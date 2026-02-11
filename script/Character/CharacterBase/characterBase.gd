extends CharacterBody2D
class_name CharacterBase

## 角色基础类 (CharacterBase)
## 职责：管理通用行为（战斗、侦查、物理、死亡）。
## 新增特性：支持 Hit & Run (走A) 机制的底层实现。

#region 1. 信号定义
signal on_dead ## 当角色死亡时发出此信号
signal on_perform_attack(target: CharacterBase) ## [新增] 当自动攻击蓄力完成时触发，子类需连接此信号执行具体攻击
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
@export var target_types: Array[CharacterType] = []            
@export var flipped_horizontal: bool = false                   
@export var health: int = 100                                  
#endregion

#region 4. 自动攻击配置
@export_group("Auto Attack System")
# 注意：开关逻辑已移交子类控制，此处只保留参数
@export var attack_interval: float = 1.0        ## 攻击间隔 (秒)
@export var attack_bar: ProgressBar             ## 引用：头顶的圆形进度条
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
var current_target: CharacterBase = null       
var enter_Character: Array[CharacterBase] = [] 

# --- 物理计算 ---
var knockback_velocity: Vector2 = Vector2.ZERO 

# --- 自动攻击状态 ---
var _attack_timer: float = 0.0 ## 内部攻击计时器

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
func _ready() -> void:
	# 记录层级
	_initial_layer = collision_layer
	_initial_mask = collision_mask
	
	# 初始化侦查
	if detection_Area:
		detection_Area.body_entered.connect(_on_playerAttack_Area_body_entered)
		detection_Area.body_exited.connect(_on_playerAttack_Area_body_exited)
	
	# 初始化数值
	if stats and healthbar:
		healthbar.max_value = stats.max_health
		healthbar.value = stats.current_health
		stats.health_changed.connect(_on_health_changed)
		stats.died.connect(_die)
		
	# 初始化攻击进度条
	if attack_bar:
		attack_bar.visible = false
		attack_bar.value = 0

func _physics_process(delta: float) -> void:
	# 1. 处理击退
	_handle_knockback(delta)
	
	# 注意：自动攻击逻辑不再此处调用，由子类 (Player) 视情况手动调用
	
	# 子类负责 move_and_slide
#endregion

#region [新增] 自动攻击核心逻辑 (被动调用)
## [核心] 更新自动攻击进度 (由子类在合适时机调用，例如 Player 的 Auto 模式)
func update_auto_attack_progress(delta: float) -> void:
	if is_dead: return

	# 条件 1: 正在移动？ -> 立即重置进度
	# 使用 length_squared > 10.0 比 > 0 更稳定，防止浮点数漂移
	if velocity.length_squared() > 10.0:
		reset_attack_progress()
		return

	# 条件 2: 没有有效目标？ -> 重置进度
	if not is_instance_valid(current_target) or current_target.is_dead:
		reset_attack_progress()
		return

	# 条件 3: 静止且有目标 -> 开始蓄力
	_attack_timer += delta
	
	# 更新 UI
	if attack_bar:
		attack_bar.visible = true
		var ratio = clamp(_attack_timer / attack_interval, 0.0, 1.0)
		attack_bar.value = ratio * 100.0
	
	# 判定触发
	if _attack_timer >= attack_interval:
		_trigger_attack()

## [核心] 触发攻击 (内部调用)
func _trigger_attack() -> void:
	if current_target:
		# 发出信号，子类连接此信号执行具体攻击
		on_perform_attack.emit(current_target)
		# print(">>> [CharacterBase] 蓄力完成，请求攻击: ", current_target.name)
	
	# 攻击后重置计时器，准备下一发
	_attack_timer = 0.0
	if attack_bar: attack_bar.value = 0.0

## [核心] 重置进度 (由子类在不满足攻击条件时调用)
func reset_attack_progress() -> void:
	if _attack_timer == 0.0 and (attack_bar and not attack_bar.visible):
		return # 已经是重置状态，无需重复操作
		
	_attack_timer = 0.0
	if attack_bar:
		attack_bar.value = 0.0
		attack_bar.visible = false
#endregion

#region 战斗逻辑 (受击/死亡/复活)
func take_damage(amount: int, attacker_type: CharacterType, _attacker_node: Node2D = null) -> void:
	if invincible or is_dead: return
	if attacker_type == character_type: return 
	
	if stats:
		stats.take_damage(float(amount))
		print("%s 受到伤害: %d | 剩余: %d" % [name, amount, stats.current_health])

	if healthbar and stats: healthbar.value = stats.current_health
	damage_effects()
	if stats and stats.current_health <= 0: _die()

func _die() -> void:
	if is_dead: return
	is_dead = true
	on_dead.emit()
	print("%s 已死亡" % name)
	
	# 如果是玩家，切断输入
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
	
	# 死亡时隐藏攻击条
	if attack_bar: attack_bar.visible = false
	
	_play_mario_death_anim()

func _play_mario_death_anim() -> void:
	if not sprite: return
	
	z_index = 100 
	sprite.stop()
	sprite.modulate = Color(0.8, 0.8, 0.8, 1.0) 
	
	var start_y = sprite.position.y
	
	if _death_tween: _death_tween.kill()
	_death_tween = create_tween()
	
	_death_tween.tween_property(sprite, "position:y", start_y - 60, 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	_death_tween.tween_property(sprite, "position:y", start_y + 1000, 1.0)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	if character_type == CharacterType.ENEMY:
		_death_tween.tween_callback(queue_free)

func reset_status() -> void:
	print(">>> [CharacterBase] 重置角色状态: ", name)
	
	if character_type == CharacterType.PLAYER:
		GameInputEvents.input_enabled = true
	
	if _death_tween: _death_tween.kill()
	if _damage_tween: _damage_tween.kill()
	
	is_dead = false
	invincible = false
	velocity = Vector2.ZERO
	z_index = 0
	
	# 重置攻击进度
	_attack_timer = 0.0
	if attack_bar:
		attack_bar.value = 0.0
		attack_bar.visible = false

	enter_Character.clear()
	current_target = null
	current_tag = 0
	
	set_physics_process(true)
	set_process(true)
	
	collision_layer = _initial_layer
	collision_mask = _initial_mask
	var collider = get_node_or_null("CollisionShape2D")
	if collider: collider.set_deferred("disabled", false)
	
	# 重置侦查并手动扫描
	if detection_Area: 
		detection_Area.monitoring = true
		var existing_bodies = detection_Area.get_overlapping_bodies()
		for body in existing_bodies:
			if body is CharacterBase and body != self and target_types.has(body.character_type):
				if not body.is_dead:
					if not enter_Character.has(body):
						enter_Character.append(body)
						body.set_target_tag(enter_Character.size())

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

#region 侦查与索敌逻辑 (保持不变)
func _on_playerAttack_Area_body_entered(body: Node2D) -> void:
	if body is CharacterBase and target_types.has(body.character_type):
		var target: CharacterBase = body
		enter_Character.append(target)
		target.set_target_tag(enter_Character.size())
		# print(">> [侦查] 锁定目标！")

func _on_playerAttack_Area_body_exited(body: Node2D) -> void:
	if body is CharacterBase and target_types.has(body.character_type):
		var target: CharacterBase = body
		var index = enter_Character.find(target)
		if index != -1:
			enter_Character.remove_at(index)
			_update_all_enter_Character()
			target.clear_target_tag()

func _update_all_enter_Character() -> void:
	for i in range(enter_Character.size()):
		enter_Character[i].set_target_tag(i + 1)

func get_closest_target() -> CharacterBase:
	var closest_target: CharacterBase = null
	var closest_dist_sq: float = INF
	var self_pos: Vector2 = global_position
	
	for body in enter_Character:
		if not is_instance_valid(body): continue
		if body != self and target_types.has(body.character_type):
			if body.is_dead: continue
			var dist_sq = self_pos.distance_squared_to(body.global_position)
			if dist_sq < closest_dist_sq:
				closest_dist_sq = dist_sq
				closest_target = body
	return closest_target

func Target_Lock_On(target: CharacterBase) -> void:
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
func Turn() -> void:
	if not sprite: return
	var default_facing = -1 if flipped_horizontal else 1
	if velocity.x < -0.1: sprite.scale.x = -default_facing
	elif velocity.x > 0.1: sprite.scale.x = default_facing

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

func die_effects() -> void: pass
func _on_health_changed(current, _max_val) -> void:
	if healthbar: healthbar.value = current

func apply_knockback(direction: Vector2, force: float) -> void:
	var weight = 1.0
	if stats and "max_weight" in stats: weight = max(1.0, stats.max_weight)
	var weight_factor = weight * 0.1 
	var final_knockback_speed = force / max(0.1, weight_factor)
	knockback_velocity = direction * final_knockback_speed

func _handle_knockback(delta: float) -> void:
	if knockback_velocity.length_squared() > 1.0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
	else:
		knockback_velocity = Vector2.ZERO

func set_target_tag(tag: int) -> void: current_tag = tag
func clear_target_tag() -> void: current_tag = 0
#endregion
