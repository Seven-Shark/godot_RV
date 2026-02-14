extends CharacterBase
class_name Enemy

## Enemy.gd
## 职责：处理敌人的数据中心、环境力、攻击判定以及高级巡逻逻辑。
## 核心功能：管理 AI 仇恨状态，支持全图随机巡逻和定点区域巡逻（带强制脱战），并提供可视化调试功能。

#region 1. 巡逻模式与 AI 配置
enum PatrolMode {
	GLOBAL_RANDOM, ## [模式1] 全图随机巡逻
	FIXED_AREA     ## [模式2] 固定区域巡逻 (带强制脱战)
}

@export_group("Patrol Settings")
@export var patrol_mode: PatrolMode = PatrolMode.GLOBAL_RANDOM
@export var patrol_radius: float = 300.0       ## [固定模式] 巡逻半径
@export var max_chase_distance: float = 500.0  ## [固定模式] 最大追击距离 (超出此距离强制脱战)
@export var patrol_wait_min: float = 1.0       ## 到达巡逻点后的最小等待时间
@export var patrol_wait_max: float = 3.0       ## 到达巡逻点后的最大等待时间

@export_group("AI Settings")
@export var attack_distance: float = 120.0  ## [供状态机读取] 攻击触发距离
@export var retreat_distance: float = 70.0  ## [供状态机读取] 后退距离
@export var aggro_trigger_time: float = 1.0 ## 仇恨触发时间
@export var aggro_lose_time: float = 3.0    ## 仇恨丢失时间

@export_group("Physics Forces")
@export var separation_force: float = 500.0 ## 分离力度
@export var push_force: float = 800.0       ## 推挤力度
@export var push_threshold: float = 80.0    ## 推挤半径

@export_group("Debug Visualization")
@export var show_patrol_area: bool = false  ## [调试] 显示固定巡逻范围(绿)、追击极限(红)及中心点
@export var show_path_line: bool = false    ## [调试] 显示当前移动目标点连线(黄)
#endregion

#region 2. 攻击配置
@export_group("Attack Settings")
@export var attack_range_length: float = 150.0 ## 攻击框长度
@export var attack_width: float = 60.0         ## 攻击框宽度
@export var charge_duration: float = 1.0       ## [供状态机读取] 蓄力时间
@export var attack_cooldown: float = 2.0       ## [供状态机读取] 冷却时间

@export_flags_2d_physics var attack_target_mask: int = 1 ## 攻击目标层级
#endregion

#region 3. 内部共享数据
# --- 仇恨相关 ---
var is_aggro_active: bool = false
var aggro_timer: float = 0.0

# --- 巡逻相关 ---
var spawn_position: Vector2      ## 出生点 (固定巡逻的中心)
var is_returning: bool = false   ## [状态标志] 是否正在强制返航中
var current_patrol_target: Vector2 = Vector2.ZERO ## 当前巡逻目标点

# --- 攻击节点 ---
var attack_pivot: Node2D
var attack_visual: ColorRect
var attack_area: Area2D
#endregion

#region 4. 节点引用
@onready var state_machine: NodeStateMachine = get_node_or_null("StateMachine")
#endregion

#region 生命周期
func _ready() -> void:
	super._ready()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_setup_attack_nodes()
	
	# 初始化巡逻数据
	spawn_position = global_position 
	if patrol_mode == PatrolMode.GLOBAL_RANDOM:
		current_patrol_target = global_position
	else:
		current_patrol_target = _get_random_point_in_circle(spawn_position, patrol_radius)

func _physics_process(delta: float) -> void:
	# [新增] 每帧请求重绘 Debug 图形
	if show_patrol_area or show_path_line:
		queue_redraw()

	# [新增] 强制返航逻辑优先于一切 (最高优先级)
	if is_returning:
		_process_return_logic(delta)
		move_and_slide()
		return 

	super._physics_process(delta)
	
	# 1. 索敌与目标状态检查
	_update_target_logic(delta)
	
	# 2. 仇恨计时逻辑
	_update_aggro_system(delta)
	
	# 3. 物理力计算 (环境斥力)
	var env_force = _calculate_environment_forces()
	velocity += env_force + knockback_velocity
	
	if knockback_velocity.length_squared() > 2500.0:
		velocity = knockback_velocity
		
	# 4. [新增] 固定巡逻模式的距离检查
	if patrol_mode == PatrolMode.FIXED_AREA and is_aggro_active:
		var dist_to_spawn = global_position.distance_to(spawn_position)
		if dist_to_spawn > max_chase_distance:
			start_forced_return() # 触发强制返航
			
	move_and_slide()

## [新增] 调试绘图逻辑
func _draw() -> void:
	# 1. 绘制固定巡逻区域信息 (仅在 FIXED_AREA 模式下生效)
	if show_patrol_area and patrol_mode == PatrolMode.FIXED_AREA:
		var center_local = to_local(spawn_position)
		# 绿色实心圆点：出生中心
		draw_circle(center_local, 5.0, Color.GREEN)
		# 绿色空心圆：巡逻半径
		draw_arc(center_local, patrol_radius, 0, TAU, 64, Color.GREEN, 1.0)
		# 红色空心圆：最大追击/脱战距离
		draw_arc(center_local, max_chase_distance, 0, TAU, 64, Color.RED, 1.5)

	# 2. [修复逻辑] 绘制当前移动目标连线 (动态判断真实目标)
	if show_path_line:
		var real_destination = Vector2.ZERO
		
		# [优先级 1] 正在强制返航 -> 目标是出生点
		if is_returning:
			real_destination = spawn_position
			
		# [优先级 2] 正在追逐 -> 目标是玩家 (且玩家存活)
		elif is_instance_valid(current_target) and not current_target.is_dead:
			real_destination = current_target.global_position
			
		# [优先级 3] 正在巡逻 -> 目标是巡逻点
		elif current_patrol_target != Vector2.ZERO:
			real_destination = current_patrol_target
		
		# 开始绘制
		if real_destination != Vector2.ZERO:
			# 将全局坐标转为本地坐标用于绘图
			var target_local = to_local(real_destination)
			
			# 连线颜色区分状态：
			# 返航 = 青色 (CYAN)
			# 追逐 = 橘红色 (ORANGE_RED) 或 红色 (RED)
			# 巡逻 = 黄色 (YELLOW)
			var line_color = Color.YELLOW
			
			if is_returning: 
				line_color = Color.CYAN
			elif is_instance_valid(current_target): 
				line_color = Color.ORANGE_RED # 修复：加了下划线，或者直接用 Color.RED
			
			# 绘制连线
			draw_line(Vector2.ZERO, target_local, line_color, 2.0)
			
			# 绘制目标点的小叉叉 (X标记)
			var cross_size = 8.0
			draw_line(target_local + Vector2(-cross_size, -cross_size), target_local + Vector2(cross_size, cross_size), line_color, 2.0)
			draw_line(target_local + Vector2(cross_size, -cross_size), target_local + Vector2(-cross_size, cross_size), line_color, 2.0)

## [重写] 重置状态
func reset_status() -> void:
	super.reset_status() # 执行父类重置(身体、血量)
	force_stop_aggro()   # 执行AI重置(脑子、仇恨)
	
	# 重置位置到出生点 (可选)
	# global_position = spawn_position
	is_returning = false
	
	print(">>> [Enemy] AI与状态已重置")
#endregion

#region 核心辅助逻辑 (巡逻与返航)

## 开始强制返航
func start_forced_return() -> void:
	print(">>> [Enemy] 追太远了！强制脱战返航！")
	is_returning = true
	force_stop_aggro() # 清除当前仇恨
	
	# 切换状态机到 Return 状态
	if state_machine:
		state_machine.transition_to("Return")

## 处理返航移动
func _process_return_logic(_delta: float) -> void:
	var dir = (spawn_position - global_position).normalized()
	
	# 1. 设置速度 (稍微快一点 1.5倍)
	if stats:
		velocity = dir * stats.base_walk_speed * 1.5
	
	# 2. 处理朝向
	if sprite:
		var default_facing = -1 if flipped_horizontal else 1
		if dir.x > 0: sprite.scale.x = default_facing
		elif dir.x < 0: sprite.scale.x = -default_facing

	# 3. 判断是否回到家了
	if global_position.distance_to(spawn_position) < 10.0:
		is_returning = false
		velocity = Vector2.ZERO
		print(">>> [Enemy] 已回到巡逻区，恢复正常 AI")
		
		if state_machine:
			state_machine.transition_to("Idle")

## [API] 获取下一个巡逻目标点 (供状态机直接调用)
func get_next_patrol_point() -> Vector2:
	var next_point = Vector2.ZERO
	
	if patrol_mode == PatrolMode.FIXED_AREA:
		# 固定区域：围绕出生点随机
		next_point = _get_random_point_in_circle(spawn_position, patrol_radius)
	else:
		# 全图随机：围绕当前位置向外随机延伸
		next_point = _get_random_point_in_circle(global_position, 200.0) 
	
	# ------------------------------------------------------------------
	# [核心修复] 将计算出的新点，同步更新给 Enemy 自己的变量
	# 这样 _draw() 方法才能读到最新的数据，画线才会变
	# ------------------------------------------------------------------
	current_patrol_target = next_point
	
	return next_point

## 辅助：获取圆内随机点
func _get_random_point_in_circle(center: Vector2, radius: float) -> Vector2:
	var angle = randf() * TAU
	var dist = sqrt(randf()) * radius 
	return center + Vector2(cos(angle), sin(angle)) * dist
#endregion

#region 核心辅助逻辑 (仇恨与战斗)

## 强制停止仇恨 (用于死亡/重置)
func force_stop_aggro() -> void:
	is_aggro_active = false
	aggro_timer = 0.0
	current_target = null
	
	if attack_visual: attack_visual.visible = false
	if attack_area: attack_area.monitoring = false
	
	if state_machine and state_machine.has_method("reset"):
		state_machine.reset()

## 目标逻辑更新
func _update_target_logic(_delta: float) -> void:
	# 检查目标是否死亡
	if is_instance_valid(current_target) and current_target.is_dead:
		force_stop_aggro()
		return

	Target_Lock_On(current_target)
	
	# 寻找新目标
	if not is_instance_valid(current_target):
		current_target = get_closest_target()

## 辅助：面向目标 (供State调用)
func face_current_target() -> void:
	if not is_instance_valid(current_target) or not sprite: return
	
	var diff_x = current_target.global_position.x - global_position.x
	if abs(diff_x) < 1.0: return
	
	var default_facing = -1 if flipped_horizontal else 1
	if diff_x < 0: sprite.scale.x = -default_facing
	else: sprite.scale.x = default_facing

## 初始化攻击节点
func _setup_attack_nodes() -> void:
	attack_pivot = Node2D.new()
	add_child(attack_pivot)
	
	attack_visual = ColorRect.new()
	attack_pivot.add_child(attack_visual)
	attack_visual.color = Color(1.0, 0.2, 0.2, 0.6)
	attack_visual.visible = false
	attack_visual.position.y = -attack_width / 2.0
	attack_visual.size = Vector2(0, attack_width)
	
	attack_area = Area2D.new()
	attack_pivot.add_child(attack_area)
	attack_area.collision_layer = 0
	attack_area.collision_mask = attack_target_mask
	attack_area.monitoring = false
	
	var col = CollisionShape2D.new()
	attack_area.add_child(col)
	var rect = RectangleShape2D.new()
	rect.size = Vector2(attack_range_length, attack_width)
	col.shape = rect
	col.position = Vector2(attack_range_length / 2.0, 0)

## 仇恨系统计算
func _update_aggro_system(delta: float) -> void:
	if is_dead: return
	
	var has_target = false
	if is_instance_valid(current_target) and not current_target.is_dead:
		if enter_Character.has(current_target):
			has_target = true
	
	if has_target:
		# [场景 A] 目标在视野内
		if not is_aggro_active:
			aggro_timer += delta
			if aggro_timer >= aggro_trigger_time:
				is_aggro_active = true
		else:
			aggro_timer = aggro_lose_time
	else:
		# [场景 B] 目标不在视野内 (跑了)
		if is_aggro_active:
			# 情况 1: 已经在追了 -> 开始倒计时
			aggro_timer -= delta
			if aggro_timer <= 0:
				is_aggro_active = false
				current_target = null 
				print(">>> [Enemy] 仇恨时间结束，放弃追逐")
		else:
			# 情况 2: 还没开始追就跑了 -> 直接遗忘！
			aggro_timer = 0.0
			if current_target != null:
				current_target = null

## 环境力计算
func _calculate_environment_forces() -> Vector2:
	if not detection_Area: return Vector2.ZERO
	var neighbors = detection_Area.get_overlapping_bodies()
	if neighbors.is_empty(): return Vector2.ZERO
	
	var total_separation = Vector2.ZERO
	var total_push = Vector2.ZERO
	var sep_count = 0
	
	for body in neighbors:
		if body == self: continue
		var diff = global_position - body.global_position
		var dist_sq = diff.length_squared()
		
		# 队友分离
		if body is Enemy and dist_sq < 2500.0 and dist_sq > 0.1:
			total_separation += (diff / sqrt(dist_sq))
			sep_count += 1
		# 玩家推挤
		elif body is CharacterBase and body.character_type == CharacterType.PLAYER:
			var threshold_sq = push_threshold * push_threshold
			if dist_sq < threshold_sq and dist_sq > 0.1:
				var dist = sqrt(dist_sq)
				var weight = 1.0 - (dist / push_threshold)
				total_push += (diff / dist) * push_force * weight

	if sep_count > 0:
		total_separation = (total_separation / sep_count) * separation_force
		
	return total_separation + total_push
#endregion
