extends CharacterBase
class_name Enemy

## Enemy.gd
## 职责：作为敌人的数据中心，处理环境物理力，初始化攻击判定。
## 核心功能：管理 AI 仇恨状态，并负责在目标死亡或重置时强制停止行为。

#region 1. AI 基础配置
@export_group("AI Settings")
@export var attack_distance: float = 120.0  ## [供状态机读取] 攻击触发距离
@export var retreat_distance: float = 70.0  ## [供状态机读取] 后退距离
@export var aggro_trigger_time: float = 1.0 ## 仇恨触发时间
@export var aggro_lose_time: float = 3.0    ## 仇恨丢失时间

@export_group("Physics Forces")
@export var separation_force: float = 500.0 ## 分离力度
@export var push_force: float = 800.0       ## 推挤力度
@export var push_threshold: float = 80.0    ## 推挤半径
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
var is_aggro_active: bool = false
var aggro_timer: float = 0.0
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

func _physics_process(delta: float) -> void:
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
		
	move_and_slide()

## [重写] 重置状态
func reset_status() -> void:
	super.reset_status() # 执行父类重置(身体、血量)
	force_stop_aggro()   # 执行AI重置(脑子、仇恨)
	print(">>> [Enemy] AI与状态已重置")
#endregion

#region 核心辅助逻辑

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
			# [核心修复] 如果还没建立仇恨，且目标已经不在视野里，立刻放弃锁定
			aggro_timer = 0.0
			if current_target != null:
				current_target = null
				# print(">>> [Enemy] 目标未触发仇恨即离开，解除锁定")

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
