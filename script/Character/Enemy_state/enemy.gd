extends CharacterBase
class_name Enemy

## Enemy.gd
## 职责：处理敌人的数据中心、环境力、攻击判定以及高级巡逻逻辑。
## 功能：管理 AI 仇恨状态，支持寻路避障系统，并严格处理导航地图同步问题。

#region 1. 巡逻模式与 AI 配置
@export_group("Patrol Settings")
@export var patrol_mode: PatrolMode = PatrolMode.GLOBAL_RANDOM ## 巡逻模式
@export var patrol_radius: float = 300.0 ## 巡逻半径 (固定区域模式下的总活动半径)
@export var patrol_wander_min: float = 100.0 ## 单次移动最小距离
@export var patrol_wander_max: float = 300.0 ## 单次移动最大距离
@export var max_chase_distance: float = 500.0 ## 最大追击距离
@export var patrol_wait_min: float = 1.0 ## 最小等待时间
@export var patrol_wait_max: float = 3.0 ## 最大等待时间
@export_flags_2d_physics var wall_layer_mask: int = 16 ## 空气墙的物理层级 (默认 Layer 5)

# [修改] 防卡死检测配置 - 分级处理
@export_subgroup("Stuck Detection")
@export var stuck_check_radius: float = 20.0 ## 防卡死检测半径
@export var stuck_retry_time: float = 2.0 ## 第一阶段：尝试换个随机点的时间
@export var stuck_escape_time: float = 1.5 ## 第二阶段：强制反向逃逸的时间 (累加在第一阶段后)

@export_group("AI Settings")
@export var attack_distance: float = 120.0 ## 攻击触发距离
@export var retreat_distance: float = 70.0 ## 后退距离
@export var aggro_trigger_time: float = 1.0 ## 仇恨触发时间
@export var aggro_lose_time: float = 3.0 ## 仇恨丢失时间

@export_group("Physics Forces")
@export var separation_force: float = 500.0 ## 分离力度 (软碰撞)
@export var push_force: float = 800.0 ## 推挤力度
@export var push_threshold: float = 80.0 ## 推挤半径

@export_group("Debug Visualization")
@export var show_patrol_area: bool = false ## 显示巡逻范围调试信息
@export var show_path_line: bool = false ## 显示移动路径连线
#endregion

#region 2. 攻击配置
@export_group("Attack Settings")
@export var attack_range_length: float = 150.0 ## 攻击框长度
@export var attack_width: float = 60.0 ## 攻击框宽度
@export var charge_duration: float = 1.0 ## 蓄力时间
@export var attack_cooldown: float = 2.0 ## 冷却时间
@export_flags_2d_physics var attack_target_mask: int = 1 ## 攻击目标层级
#endregion

#region 3. 内部共享数据
enum PatrolMode { GLOBAL_RANDOM, FIXED_AREA } ## 巡逻枚举定义

# --- 仇恨与状态 ---
var is_aggro_active: bool = false ## 是否处于仇恨激活状态
var aggro_timer: float = 0.0 ## 仇恨计时器
var spawn_position: Vector2 ## 初始出生点
var is_returning: bool = false ## 是否正在强制返航
var current_patrol_target: Vector2 = Vector2.ZERO ## 当前巡逻目标坐标点

# 分离力开关
var is_separation_active: bool = true 

# --- 节点与代理 ---
var attack_pivot: Node2D ## 攻击方向基准点
var attack_visual: ColorRect ## 攻击范围预览
var attack_area: Area2D ## 攻击判定区域
@onready var state_machine: NodeStateMachine = get_node_or_null("StateMachine") ## 状态机引用
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D ## 导航代理组件
#endregion

#region 生命周期与核心循环

## 初始化组件、配置导航并等待地图同步
func _ready() -> void:
	super._ready()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_setup_attack_nodes()
	
	if nav_agent:
		nav_agent.path_desired_distance = 20.0
		nav_agent.target_desired_distance = 10.0
		if not nav_agent.velocity_computed.is_connected(_on_nav_velocity_computed):
			nav_agent.velocity_computed.connect(_on_nav_velocity_computed)
	
	spawn_position = global_position 
	current_patrol_target = global_position
	
	# 等待两帧，让 NavigationServer 完成第一次同步
	await get_tree().physics_frame
	await get_tree().physics_frame

## 处理调试绘图、返航逻辑、环境力及移动更新
func _physics_process(delta: float) -> void:
	if show_patrol_area or show_path_line: queue_redraw()
	
	if is_returning:
		_process_return_logic(delta)
		move_and_slide()
		return 

	super._physics_process(delta)
	_update_target_logic(delta)
	_update_aggro_system(delta)
	
	var env_force = _calculate_environment_forces()
	velocity += env_force + knockback_velocity
	
	if knockback_velocity.length_squared() > 2500.0: velocity = knockback_velocity
		
	if patrol_mode == PatrolMode.FIXED_AREA and is_aggro_active:
		if global_position.distance_to(spawn_position) > max_chase_distance:
			start_forced_return()
			
	move_and_slide()

## 绘制调试路径、巡逻圆圈及中心点
func _draw() -> void:
	if show_patrol_area and patrol_mode == PatrolMode.FIXED_AREA:
		var center_local = to_local(spawn_position)
		draw_circle(center_local, 5.0, Color.GREEN)
		draw_arc(center_local, patrol_radius, 0, TAU, 64, Color.GREEN, 1.0)
		draw_arc(center_local, max_chase_distance, 0, TAU, 64, Color.RED, 1.5)

	if show_path_line:
		var real_destination = Vector2.ZERO
		if is_returning: real_destination = spawn_position
		elif is_instance_valid(current_target) and not current_target.is_dead: real_destination = current_target.global_position
		elif current_patrol_target != Vector2.ZERO: real_destination = current_patrol_target
		
		if real_destination != Vector2.ZERO:
			var target_local = to_local(real_destination)
			var line_color = Color.YELLOW
			if is_returning: line_color = Color.CYAN
			elif is_instance_valid(current_target): line_color = Color.ORANGE_RED 
			draw_line(Vector2.ZERO, target_local, line_color, 2.0)

#endregion

#region 智能寻路系统 API (分类：寻路与避障)

## 设置通用的导航目标点
func set_navigation_target(target_pos: Vector2) -> void:
	if nav_agent: nav_agent.target_position = target_pos

## 获取新巡逻点并设置为导航目标
func set_navigation_target_to_patrol_point() -> void:
	var next_point = get_next_patrol_point()
	set_navigation_target(next_point)

## 处理导航移动计算，并根据结果返回是否到达
func process_navigation_movement(speed: float) -> bool:
	if not nav_agent: return true
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return true
		
	var next_path_pos = nav_agent.get_next_path_position()
	var new_velocity = (next_path_pos - global_position).normalized() * speed
	
	if sprite:
		if new_velocity.x > 0.1: sprite.scale.x = 1
		elif new_velocity.x < -0.1: sprite.scale.x = -1
	
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(new_velocity)
	else:
		velocity = new_velocity
	return false

## 接收导航代理计算出的避障安全速度
func _on_nav_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity

#endregion

#region 巡逻与地图安全逻辑 (分类：核心辅助逻辑)

## 获取下一个有效的巡逻点 (三重验证版)
func get_next_patrol_point() -> Vector2:
	var map_rid = get_world_2d().get_navigation_map()
	
	# [核心拦截] 检查地图同步迭代 ID
	if NavigationServer2D.map_get_iteration_id(map_rid) == 0:
		return global_position

	var max_attempts = 15 # 增加尝试次数，确保能随到合法的
	
	for i in range(max_attempts):
		var next_point = Vector2.ZERO
		
		# 1. 生成随机点
		if patrol_mode == PatrolMode.FIXED_AREA:
			# 固定区域模式：依然是在出生点周围随机
			next_point = _get_random_point_in_range(spawn_position, 0.0, patrol_radius) 
		else:
			# 全局随机模式：基于当前位置，在 min ~ max 范围内找点
			next_point = _get_random_point_in_range(global_position, patrol_wander_min, patrol_wander_max)
		
		# [验证 1] 点位物理检测
		if _is_position_inside_wall(next_point):
			continue 

		# [验证 2] 射线路径检测
		if not _is_point_safe_by_raycast(global_position, next_point):
			continue 
			
		# [验证 3] 导航吸附检测
		var safe_point = NavigationServer2D.map_get_closest_point(map_rid, next_point)
		
		if next_point.distance_to(safe_point) > 5.0:
			continue 
			
		current_patrol_target = safe_point
		return safe_point

	return global_position


## [新增] 获取一个“反向逃逸”的巡逻点 (专门用于二阶段解卡)
func get_escape_patrol_point() -> Vector2:
	# 1. 获取当前意图前进的方向
	var forward_dir = Vector2.RIGHT # 默认值
	
	if not nav_agent.is_navigation_finished():
		# 如果正在寻路，取下一个路点的方向
		forward_dir = (nav_agent.get_next_path_position() - global_position).normalized()
	elif velocity.length_squared() > 1.0:
		# 如果有速度，取速度方向
		forward_dir = velocity.normalized()
	
	# 2. 计算反方向 (背后的方向)
	var backward_base_dir = -forward_dir
	
	# 3. 尝试寻找合法的反向点 (尝试 10 次)
	# 我们不完全沿直线后退，而是在背后 120 度扇形范围内随机，避免正后方也被堵死
	var max_attempts = 10
	var map_rid = get_world_2d().get_navigation_map()
	
	for i in range(max_attempts):
		# 在反方向基础上左右随机偏移 +/- 60度
		var random_angle = deg_to_rad(randf_range(-60, 60))
		var escape_dir = backward_base_dir.rotated(random_angle)
		
		# 随机逃逸距离 (使用最大移动距离，确保跑得够远)
		var dist = randf_range(patrol_wander_min, patrol_wander_max)
		var next_point = global_position + escape_dir * dist
		
		# --- 执行安全性检查 ---
		if _is_position_inside_wall(next_point): continue 
		if not _is_point_safe_by_raycast(global_position, next_point): continue 
		var safe_point = NavigationServer2D.map_get_closest_point(map_rid, next_point)
		if next_point.distance_to(safe_point) > 5.0: continue
		
		# 找到合法逃逸点
		current_patrol_target = safe_point
		return safe_point

	# 4. 如果身后全是墙，兜底返回普通随机点
	return get_next_patrol_point()

## [新增] 检测某个点坐标是否位于墙体碰撞内
func _is_position_inside_wall(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collision_mask = wall_layer_mask # 检测空气墙层级
	
	# intersect_point 返回与该点重叠的所有碰撞体列表
	var results = space_state.intersect_point(params, 1) 
	
	return not results.is_empty() # 如果不为空，说明点在墙里

## 使用物理射线判断路径上是否存在空气墙
func _is_point_safe_by_raycast(start: Vector2, target: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(start, target, wall_layer_mask)
	var result = space_state.intersect_ray(query)
	return result.is_empty()

## 触发强制返航状态
func start_forced_return() -> void:
	is_returning = true
	force_stop_aggro() 
	if state_machine: state_machine.transition_to("Return")

## 执行返航时的移动物理逻辑
func _process_return_logic(_delta: float) -> void:
	var dir = (spawn_position - global_position).normalized()
	if stats: velocity = dir * stats.base_walk_speed * 1.5
	if sprite:
		var default_facing = -1 if flipped_horizontal else 1
		if dir.x > 0: sprite.scale.x = default_facing
		elif dir.x < 0: sprite.scale.x = -default_facing
	if global_position.distance_to(spawn_position) < 10.0:
		is_returning = false
		velocity = Vector2.ZERO
		if state_machine: state_machine.transition_to("Idle")

## 辅助函数：在圆范围内获取随机点
func _get_random_point_in_range(center: Vector2, min_dist: float, max_dist: float) -> Vector2:
	var angle = randf() * TAU 
	var dist = randf_range(min_dist, max_dist)
	return center + Vector2(cos(angle), sin(angle)) * dist

#endregion

#region 仇恨与战斗系统逻辑 (分类：核心辅助逻辑)

## 强制清除仇恨并重置攻击相关组件
func force_stop_aggro() -> void:
	is_aggro_active = false
	aggro_timer = 0.0
	current_target = null
	if attack_visual: attack_visual.visible = false
	if attack_area: attack_area.monitoring = false
	if state_machine and state_machine.has_method("reset"): state_machine.reset()

## 实时更新目标有效性与锁定逻辑
func _update_target_logic(_delta: float) -> void:
	if is_instance_valid(current_target) and current_target.is_dead:
		force_stop_aggro(); return
	Target_Lock_On(current_target)
	if not is_instance_valid(current_target): current_target = get_closest_target()

## 辅助：面向目标 (供 Attack State 调用)
func face_current_target() -> void:
	if not is_instance_valid(current_target) or not sprite: 
		return
	var diff_x = current_target.global_position.x - global_position.x
	if abs(diff_x) < 5.0: 
		return
	if diff_x > 0: sprite.scale.x = 1 
	else: sprite.scale.x = -1 

## 初始化并配置攻击预览与判定节点
func _setup_attack_nodes() -> void:
	attack_pivot = Node2D.new(); add_child(attack_pivot)
	attack_visual = ColorRect.new(); attack_pivot.add_child(attack_visual)
	attack_visual.color = Color(1.0, 0.2, 0.2, 0.6); attack_visual.visible = false
	attack_visual.position.y = -attack_width / 2.0; attack_visual.size = Vector2(0, attack_width)
	attack_area = Area2D.new(); attack_pivot.add_child(attack_area)
	attack_area.collision_layer = 0; attack_area.collision_mask = attack_target_mask
	var col = CollisionShape2D.new(); attack_area.add_child(col)
	var rect = RectangleShape2D.new(); rect.size = Vector2(attack_range_length, attack_width)
	col.shape = rect; col.position = Vector2(attack_range_length / 2.0, 0)

## 更新仇恨计时系统及仇恨状态切换
func _update_aggro_system(delta: float) -> void:
	if is_dead: return
	var has_target = is_instance_valid(current_target) and not current_target.is_dead and enter_Character.has(current_target)
	if has_target:
		if not is_aggro_active:
			aggro_timer += delta
			if aggro_timer >= aggro_trigger_time: is_aggro_active = true
		else: aggro_timer = aggro_lose_time
	elif is_aggro_active:
		aggro_timer -= delta
		if aggro_timer <= 0: is_aggro_active = false; current_target = null 

## 计算并合并环境斥力 (升级版：支持动态滑开)
func _calculate_environment_forces() -> Vector2:
	if not detection_Area: return Vector2.ZERO
	
	var neighbors = detection_Area.get_overlapping_bodies()
	var total_separation = Vector2.ZERO
	var total_push = Vector2.ZERO
	var sep_count = 0
	var min_separation_dist = 20.0 
	
	var is_moving = velocity.length_squared() > 100.0
	var move_dir = velocity.normalized()
	
	for body in neighbors:
		if body == self: continue
		
		var diff = global_position - body.global_position
		var dist_sq = diff.length_squared()
		var dist = sqrt(dist_sq)
		
		# 1. 队友分离
		if body is Enemy:
			var force = Vector2.ZERO
			if dist < min_separation_dist:
				var effective_dist = max(0.1, dist)
				var strength = 1.0 - (effective_dist / min_separation_dist)
				force = (diff / effective_dist) * strength * 5.0
			elif dist < 35.0:
				force = (diff / dist) * 0.5
			
			if force != Vector2.ZERO:
				if is_moving:
					var dot_prod = force.dot(move_dir)
					if dot_prod < 0:
						force -= move_dir * dot_prod 
				total_separation += force
				sep_count += 1
				
		# 2. 玩家推挤
		elif body is CharacterBase and body.character_type == CharacterType.PLAYER:
			var threshold_sq = push_threshold * push_threshold
			if dist_sq < threshold_sq and dist_sq > 0.1:
				var weight = 1.0 - (dist / push_threshold)
				total_push += (diff / dist) * push_force * weight

	var final_force = Vector2.ZERO
	if sep_count > 0:
		final_force = total_separation.normalized() * separation_force
		
	return final_force + total_push

## 强制重置敌人整体状态
func reset_status() -> void:
	super.reset_status(); force_stop_aggro(); is_returning = false

#endregion
