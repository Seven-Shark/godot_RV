extends CharacterBody2D
class_name CharacterBase

## 角色基础类 (CharacterBase)
## 职责：管理通用行为（战斗、侦查、物理、死亡）。
## 新增特性：集成 Hit & Run (走A) 机制 + 攻击范围延迟判定(Hitbox)。
## 优化：
## 1. 采用常驻监测 (Always Monitoring) 方案，消除物理帧延迟。
## 2. [新增] 伤害判定白名单，可独立配置自动攻击对哪些目标生效。

#region 1. 信号定义
signal on_dead ## 当角色死亡时发出此信号
signal on_perform_attack(target: Node2D) ## 当自动攻击蓄力完成时触发
#endregion

#region 2. 枚举定义
enum CharacterType {
	ITEM,   ## 物品/箱子
	PLAYER, ## 玩家
	ENEMY   ## 敌人
}
#endregion

#region 3. 基础配置
@export_group("Base Settings")
@export var character_type: CharacterType = CharacterType.ITEM 
@export var flipped_horizontal: bool = false                    
@export var health: int = 100                                   

# [索敌配置] 决定眼睛看谁 (自动瞄准/索敌圈)
@export_group("Target Settings (Aiming)")
@export var target_types: Array[CharacterType] = []             ## 索敌的角色类型
@export var target_entity_types: Array[WorldEntity.EntityType] = [] ## 索敌的物件类型 (Prop, Nest...)

# [新增] [伤害配置] 决定刀砍谁 (Hitbox生效列表)
@export_group("Damage Rules (Hitbox)")
@export var damageable_character_types: Array[CharacterType] = [] ## 可造成伤害的角色类型
@export var damageable_entity_types: Array[WorldEntity.EntityType] = [] ## 可造成伤害的物件类型
#endregion

#region 4. 自动攻击配置
@export_group("Auto Attack System")
# 基础参数
@export var attack_interval: float = 1.0        ## 连续攻击间隔 (秒)
@export var first_attack_interval: float = 0.2  ## 首次攻击间隔
@export var attack_bar: ProgressBar             ## 头顶进度条
@export var attack_knockback_force: float = 500.0 ## 普通攻击击退力度

# 伤害判定参数
@export_subgroup("Hitbox Settings")
@export var attack_damage: int = 10             ## 攻击伤害
@export var attack_delay: float = 0.1           ## 伤害延迟 (前摇)
@export var attack_duration: float = 0.1        ## 伤害判定持续时间
@export var attack_hitbox: Area2D               ## [必须拖入] 攻击范围 Area2D 节点
#endregion

#region 5. 节点引用
@export_group("References")
@export var sprite: AnimatedSprite2D      
@export var healthbar: ProgressBar        
@export var hit_particles: GPUParticles2D 
#endregion

#region 6. 物理参数
@export_group("Physics")
@export var knockback_friction: float = 1000.0 
#endregion

#region 7. 内部状态变量
# --- 状态标志 ---
var invincible: bool = false 
var is_dead: bool = false    
var current_tag: int = 0     

# --- 侦查与索敌 ---
var current_target: Node2D = null              
var enter_Character: Array[Node2D] = []        

# --- 物理计算 ---
var knockback_velocity: Vector2 = Vector2.ZERO 

# --- 自动攻击状态 ---
var _attack_timer: float = 0.0 ## 内部攻击计时器
var _is_first_attack: bool = true ## 标记是否为停止后的第一发
var _is_attack_valid: bool = false ## 标记本次攻击判定是否有效 (用于处理移动打断)
var _is_damage_active: bool = false ## 标记 Hitbox 当前是否有伤害能力 (逻辑开关)

# --- 初始状态记忆 ---
var _initial_layer: int = 1 
var _initial_mask: int = 1  
var _death_tween: Tween  
var _damage_tween: Tween 
#endregion

#region 8. 节点获取 (OnReady)
@onready var detection_Area: Area2D = $DetectionArea                    
@onready var direction_Sign: Node2D = get_node_or_null("DirectionSign") 
@onready var stats: StatsComponent = get_node_or_null("StatsComponent") 
#endregion

#region 生命周期

## [生命周期] 节点初始化。配置物理层、信号连接，并智能兼容伤害白名单。
func _ready() -> void:
	_initial_layer = collision_layer
	_initial_mask = collision_mask
	
	# [新增] 智能兼容：如果没配置伤害列表，默认等于索敌列表 (防止升级脚本后无法攻击)
	if damageable_character_types.is_empty() and not target_types.is_empty():
		damageable_character_types = target_types.duplicate()
	if damageable_entity_types.is_empty() and not target_entity_types.is_empty():
		damageable_entity_types = target_entity_types.duplicate()
	
	if detection_Area:
		detection_Area.body_entered.connect(_on_playerAttack_Area_body_entered)
		detection_Area.body_exited.connect(_on_playerAttack_Area_body_exited)
	
	if stats and healthbar:
		healthbar.max_value = stats.max_health
		healthbar.value = stats.current_health
		stats.health_changed.connect(_on_health_changed)
		stats.died.connect(_die)
		
	if attack_bar:
		attack_bar.visible = false
		attack_bar.value = 0
	
	# 初始化 Hitbox 为常驻开启状态，但逻辑关闭
	if attack_hitbox:
		attack_hitbox.monitoring = true
		attack_hitbox.monitorable = false
		_is_damage_active = false
		
		# 提前连接信号
		if not attack_hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			attack_hitbox.body_entered.connect(_on_hitbox_body_entered)

## [生命周期] 物理帧更新。每帧处理角色受到的击退位移衰减。
func _physics_process(delta: float) -> void:
	_handle_knockback(delta)
	# 子类负责 move_and_slide
#endregion

#region 自动攻击核心逻辑

## [自动攻击] 每帧更新攻击进度。如果角色移动或目标丢失则重置进度，静止蓄力满后触发攻击。
func update_auto_attack_progress(delta: float) -> void:
	if is_dead: return
 
	# 条件 1: 正在移动？ -> 完全重置 (下一次停下来算首次攻击)
	if velocity.length_squared() > 10.0:
		reset_attack_progress(true) 
		return

	# 条件 2: 没有有效目标？ -> 完全重置
	var target_valid = is_instance_valid(current_target)
	if target_valid:
		if current_target is CharacterBase and current_target.is_dead:
			target_valid = false
		
	if not target_valid:
		reset_attack_progress(true)
		return

	# 条件 3: 静止且有目标 -> 开始蓄力
	var current_interval = first_attack_interval if _is_first_attack else attack_interval
	_attack_timer += delta
	
	# 更新 UI
	if attack_bar:
		# 优化：增加 0.05秒 的视觉阈值，防止闪烁
		attack_bar.visible = _attack_timer > 0.05
		var ratio = clamp(_attack_timer / current_interval, 0.0, 1.0)
		attack_bar.value = ratio * 100.0
	
	# 判定触发
	if _attack_timer >= current_interval:
		_trigger_attack()

## [自动攻击] 触发单次攻击。发射动画信号、重置读条，并异步启动伤害判定序列。
func _trigger_attack() -> void:
	if current_target:
		on_perform_attack.emit(current_target)
	
	# 1. 逻辑重置
	_attack_timer = 0.0
	_is_first_attack = false 
	
	# 2. [核心] 发放攻击有效性标记
	_is_attack_valid = true
	
	# 3. 启动伤害判定流程 (异步执行)
	_perform_attack_sequence()

## [自动攻击] 强行重置攻击读条和 UI。可选参数控制是否彻底重置“首发攻击”状态。
func reset_attack_progress(is_full_reset: bool = false) -> void:
	if is_full_reset:
		_is_first_attack = true
		_is_attack_valid = false
		_is_damage_active = false
	
	if not is_full_reset and _attack_timer == 0.0:
		return
		
	_attack_timer = 0.0
	
	if attack_bar:
		attack_bar.visible = false
		attack_bar.value = 0.0
#endregion

#region 攻击伤害判定逻辑 (Hitbox Sequence)

## [伤害判定] 异步执行攻击序列流程：同步攻击朝向 -> 延迟前摇 -> 激活伤害判定 -> 延迟持续时间 -> 关闭伤害判定。
func _perform_attack_sequence() -> void:
	if not attack_hitbox: return

	# 1. 同步攻击方向
	if direction_Sign:
		attack_hitbox.global_rotation = direction_Sign.global_rotation
	
	_is_damage_active = false
	
	# 3. 等待前摇
	if attack_delay > 0:
		await get_tree().create_timer(attack_delay).timeout
		if not _is_attack_valid: return
		if not is_instance_valid(self) or is_dead: return
	
	# 4. 开启伤害逻辑
	_is_damage_active = true
	
	# 4.1 立即处理已经在圈里的敌人
	_process_hitbox_overlap()
	
	# 5. 等待持续时间
	if attack_duration > 0:
		await get_tree().create_timer(attack_duration).timeout
	
	# 6. 关闭伤害逻辑
	_is_damage_active = false

## [伤害判定] 瞬间遍历并处理当前处于 Hitbox 范围内的所有碰撞体。
func _process_hitbox_overlap() -> void:
	var bodies = attack_hitbox.get_overlapping_bodies()
	for body in bodies:
		_apply_damage_to(body)

## [伤害判定] 信号回调：当伤害判定激活期间，如果有新物理体走进了 Hitbox，则尝试对其造成伤害。
func _on_hitbox_body_entered(body: Node2D) -> void:
	if not _is_damage_active: return
	_apply_damage_to(body)

## [核心修改] 统一造成伤害 (普通攻击)。经过严密的白名单和阵营判定后，真实扣减目标血量并施加击退。
func _apply_damage_to(body: Node2D) -> void:
	if body == self: return 
	if not body.has_method("take_damage"): return
	
	# --- 权限检查 (Whitelist) ---
	var is_allowed_damage = false
	
	# 1. 检查 CharacterBase (敌人/玩家/物品)
	if body is CharacterBase:
		# 防止同阵营伤害 (Friendly Fire)
		if body.character_type == self.character_type:
			return 
		# 检查是否在允许伤害的列表中
		if damageable_character_types.has(body.character_type):
			is_allowed_damage = true
			
	# 2. 检查 WorldEntity (巢穴/物件/树木)
	elif body is WorldEntity:
		# 检查是否在允许伤害的列表中
		if damageable_entity_types.has(body.entity_type):
			is_allowed_damage = true
	
	# 如果不在白名单里，直接跳过，不造成伤害
	if not is_allowed_damage:
		# print(">>> 攻击命中 %s，但目标类型不在伤害白名单中，已忽略。" % body.name)
		return
	
	# --- 执行伤害 ---
	# A. 扣血
	body.take_damage(float(attack_damage), self.character_type, self)
	
	# B. 施加击退
	var knockback_dir = (body.global_position - global_position).normalized()
	
	if body.has_method("apply_knockback"):
		body.apply_knockback(knockback_dir, attack_knockback_force)
	elif body is RigidBody2D:
		body.apply_central_impulse(knockback_dir * attack_knockback_force * 0.5)
#endregion

#region 战斗逻辑 (受击/死亡/复活)

## [战斗逻辑] 处理角色受到伤害的过程。扣血，触发受击特效，并在血量归零时触发死亡。
func take_damage(amount: int, attacker_type: CharacterType, _attacker_node: Node2D = null) -> void:
	if invincible or is_dead: return
	if attacker_type == character_type: return 
	
	if stats:
		stats.take_damage(float(amount))
		print("%s 受到伤害: %d | 剩余: %d" % [name, amount, stats.current_health])

	if healthbar and stats: healthbar.value = stats.current_health
	damage_effects()
	if stats and stats.current_health <= 0: _die()

## [战斗逻辑] 执行死亡流程。切断所有物理计算、屏蔽按键输入、清空碰撞层，并调用死亡动画。
func _die() -> void:
	if is_dead: return
	is_dead = true
	on_dead.emit()
	print("%s 已死亡" % name)
	
	if character_type == CharacterType.PLAYER:
		GameInputEvents.input_enabled = false
	
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process(false)
	
	collision_layer = 0
	collision_mask = 0
	var collider = get_node_or_null("CollisionShape2D")
	if collider: collider.set_deferred("disabled", true)
	
	if detection_Area: detection_Area.monitoring = false
	if healthbar: healthbar.visible = false
	if direction_Sign: direction_Sign.visible = false
	if attack_bar: attack_bar.visible = false
	
	_is_damage_active = false
	if attack_hitbox: attack_hitbox.set_deferred("monitoring", false)
	
	_play_mario_death_anim()

## [视觉动画] 播放马里奥式的经典死亡演出动画（往上蹦一下然后掉落屏幕外），如果是敌人则自动销毁节点。
func _play_mario_death_anim() -> void:
	if not sprite: return
	z_index = 100 
	sprite.stop()
	sprite.modulate = Color(0.8, 0.8, 0.8, 1.0) 
	var start_y = sprite.position.y
	if _death_tween: _death_tween.kill()
	_death_tween = create_tween()
	_death_tween.tween_property(sprite, "position:y", start_y - 60, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_death_tween.tween_property(sprite, "position:y", start_y + 1000, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if character_type == CharacterType.ENEMY: _death_tween.tween_callback(queue_free)

## [状态恢复] 将角色完全重置到存活并满血状态。主要用于玩家重生或敌人池重置。
func reset_status() -> void:
	print(">>> [CharacterBase] 重置角色状态: ", name)
	if character_type == CharacterType.PLAYER: GameInputEvents.input_enabled = true
	if _death_tween: _death_tween.kill()
	if _damage_tween: _damage_tween.kill()
	
	is_dead = false
	invincible = false
	velocity = Vector2.ZERO
	z_index = 0
	
	_attack_timer = 0.0
	_is_first_attack = true 
	_is_attack_valid = false
	_is_damage_active = false
	
	if attack_bar:
		attack_bar.value = 0.0
		attack_bar.visible = false
	
	if attack_hitbox:
		attack_hitbox.set_deferred("monitoring", true)

	enter_Character.clear()
	current_target = null
	current_tag = 0
	
	set_physics_process(true)
	set_process(true)
	
	collision_layer = _initial_layer
	collision_mask = _initial_mask
	var collider = get_node_or_null("CollisionShape2D")
	if collider: collider.set_deferred("disabled", false)
	
	# 重启侦查圈逻辑
	if detection_Area: 
		detection_Area.monitoring = true
		var existing_bodies = detection_Area.get_overlapping_bodies()
		# 手动触发一次进入逻辑
		for body in existing_bodies:
			_on_playerAttack_Area_body_entered(body)

	if sprite:
		sprite.position = Vector2.ZERO
		sprite.modulate = Color.WHITE
		sprite.show()
		sprite.play("Idle")
	if healthbar: healthbar.visible = true
	if direction_Sign: direction_Sign.visible = false
	if stats:
		stats.reset_stats()
		if healthbar: healthbar.value = stats.current_health
#endregion

#region 侦查与索敌逻辑

## [索敌逻辑] 信号回调：当其他物理体进入角色的侦查范围圆圈时，如果符合索敌白名单配置，则加入列表。
func _on_playerAttack_Area_body_entered(body: Node2D) -> void:
	if body == self: return
	var is_valid = false
	
	# A. 敌人 (判断 target_types)
	if body is CharacterBase and target_types.has(body.character_type):
		is_valid = true
		
	# B. 物件 (判断 target_entity_types)
	elif body is WorldEntity:
		if target_entity_types.has(body.entity_type):
			is_valid = true
			
	if is_valid:
		if not enter_Character.has(body):
			enter_Character.append(body)
			if body.has_method("set_target_tag"):
				body.set_target_tag(enter_Character.size())

## [索敌逻辑] 信号回调：当其它物理体离开侦查圈时，将其移出列表，并刷新其余目标的序号标号。
func _on_playerAttack_Area_body_exited(body: Node2D) -> void:
	var index = enter_Character.find(body)
	if index != -1:
		enter_Character.remove_at(index)
		_update_all_enter_Character()
		if body.has_method("clear_target_tag"):
			body.clear_target_tag()

## [私有方法] 更新当前索敌列表中所有单位的标号。
func _update_all_enter_Character() -> void:
	for i in range(enter_Character.size()):
		var body = enter_Character[i]
		if body.has_method("set_target_tag"):
			body.set_target_tag(i + 1)

## [公共接口] 遍历当前索敌列表，计算并返回距离自己最近且存活的目标单位。
func get_closest_target() -> Node2D:
	var closest_target: Node2D = null
	var closest_dist_sq: float = INF
	var self_pos: Vector2 = global_position
	
	for body in enter_Character:
		if not is_instance_valid(body): continue
		
		var is_valid_target = false
		
		# 1. 角色类型检查
		if body is CharacterBase:
			if not body.is_dead: is_valid_target = true
			
		# 2. 物件类型检查
		elif body is WorldEntity:
			if target_entity_types.has(body.entity_type):
				is_valid_target = true
		
		if not is_valid_target: continue
			
		var dist_sq = self_pos.distance_squared_to(body.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest_target = body
			
	return closest_target

## [视觉辅助] 控制角色脚下的指向标(箭头)。有目标时指向目标，无目标移动时指向位移方向。
func Target_Lock_On(target: Node2D) -> void:
	if not is_instance_valid(direction_Sign): return
	if target:
		direction_Sign.rotation = (target.global_position - global_position).angle()
		direction_Sign.visible = true
	else:
		if velocity.length_squared() > 10.0:
			direction_Sign.rotation = velocity.angle()
			direction_Sign.visible = true
		else:
			direction_Sign.visible = false
#endregion

#region 视觉表现与辅助 (保持不变)

## [视觉表现] 根据当前的物理运动方向（velocity.x），自动水平翻转精灵图，实现左右转身。
func Turn() -> void:
	if not sprite: return
	var default_facing = -1 if flipped_horizontal else 1
	if velocity.x < -0.1: sprite.scale.x = -default_facing
	elif velocity.x > 0.1: sprite.scale.x = default_facing

## [视觉表现] 播放受击特效。角色进入短暂无敌，爆出粒子，并产生白->红->恢复正常的受击闪烁效果。
func damage_effects() -> void:
	invincible = true
	if hit_particles: hit_particles.emitting = true
	if _damage_tween: _damage_tween.kill()
	_damage_tween = create_tween()
	_damage_tween.tween_property(sprite, "modulate", Color(10, 10, 10), 0.1) 
	_damage_tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	_damage_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	await _damage_tween.finished
	invincible = false

## [预留接口] 死亡特效扩展口。
func die_effects() -> void: pass

## [UI 更新] 信号回调：响应血量变化，同步刷新头顶的血条。
func _on_health_changed(current, _max_val) -> void:
	if healthbar: healthbar.value = current

## [物理计算] 外部调用：对角色施加一次击退力。力的大小会根据 stats 中配置的体重(max_weight)进行衰减。
func apply_knockback(direction: Vector2, force: float) -> void:
	var weight = 1.0
	if stats and "max_weight" in stats: weight = max(1.0, stats.max_weight)
	var weight_factor = weight * 0.1 
	var final_knockback_speed = force / max(0.1, weight_factor)
	knockback_velocity = direction * final_knockback_speed

## [物理计算] 内部每帧处理，使击退速度在阻力(knockback_friction)作用下平滑衰减。
func _handle_knockback(delta: float) -> void:
	if knockback_velocity.length_squared() > 1.0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
	else:
		knockback_velocity = Vector2.ZERO

## [状态同步] 外部调用：标记自己在侦测数组中的标签序号。
func set_target_tag(tag: int) -> void: current_tag = tag

## [状态同步] 外部调用：清空自己的侦测标签序号。
func clear_target_tag() -> void: current_tag = 0
#endregion
