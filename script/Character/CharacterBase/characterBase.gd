extends CharacterBody2D
class_name CharacterBase

## 角色基础类 (CharacterBase)
## 职责：管理游戏中所有角色的通用行为，包括战斗、侦查、物理反馈和死亡逻辑。
## 特性：支持初始层级记忆(防止复活Bug)、马里奥式死亡动画、受击反馈。

#region 1. 信号定义
signal on_dead ## 当角色死亡时发出此信号
#endregion

#region 2. 枚举定义
enum CharacterType {
	ITEM,   ## 物品/箱子 (中立)
	PLAYER, ## 玩家 (友方)
	ENEMY   ## 敌人 (敌对)
}
#endregion

#region 3. 基础配置
@export_group("Base Settings")
@export var character_type: CharacterType = CharacterType.ITEM ## 当前角色的阵营类型
@export var target_types: Array[CharacterType] = []            ## 侦查列表：该角色会把哪些类型视为目标
@export var flipped_horizontal: bool = false                   ## 图片朝向修正 (勾选=默认朝左, 未勾选=默认朝右)
@export var health: int = 100                                  ## [展示用] 初始血量 (实际逻辑由 StatsComponent 接管)
#endregion

#region 4. 节点引用
@export_group("References")
@export var sprite: AnimatedSprite2D      ## 核心动画精灵
@export var healthbar: ProgressBar        ## 头部血条
@export var hit_particles: GPUParticles2D ## 受击粒子特效节点
#endregion

#region 5. 物理参数
@export_group("Physics")
@export var knockback_friction: float = 1000.0 ## 击退摩擦力 (数值越大停得越快)
#endregion

#region 6. 内部状态变量
# --- 状态标志 ---
var invincible: bool = false ## [内部] 无敌状态标记
var is_dead: bool = false    ## [内部] 死亡标记
var current_tag: int = 0     ## [内部] 索敌排序ID

# --- 侦查与索敌 ---
var current_target: CharacterBase = null       ## [内部] 当前锁定的最近目标
var enter_Character: Array[CharacterBase] = [] ## [内部] 侦查区域内的有效对象列表

# --- 物理计算 ---
var knockback_velocity: Vector2 = Vector2.ZERO ## [内部] 击退速度向量 (随时间衰减)

# --- 初始状态记忆 ---
var _initial_layer: int = 1 ## [内部] 记忆初始 Collision Layer
var _initial_mask: int = 1  ## [内部] 记忆初始 Collision Mask
#endregion

#region 7. 节点获取 (OnReady)
@onready var detection_Area: Area2D = $DetectionArea                    ## 侦查区域
@onready var direction_Sign: Node2D = get_node_or_null("DirectionSign") ## 指示箭头
@onready var stats: StatsComponent = get_node_or_null("StatsComponent") ## 属性组件
#endregion

#region 生命周期
func _ready() -> void:
	# [核心] 记录初始物理层级，防止复活后层级错乱
	_initial_layer = collision_layer
	_initial_mask = collision_mask
	
	# 初始化侦查区域
	if detection_Area:
		detection_Area.body_entered.connect(_on_playerAttack_Area_body_entered)
		detection_Area.body_exited.connect(_on_playerAttack_Area_body_exited)
	
	# 初始化数值组件
	if stats and healthbar:
		healthbar.max_value = stats.max_health
		healthbar.value = stats.current_health
		stats.health_changed.connect(_on_health_changed)
		stats.died.connect(_die)

func _physics_process(delta: float) -> void:
	# 处理击退物理
	_handle_knockback(delta)
	# 子类负责 move_and_slide
#endregion

#region 战斗逻辑 (受击/死亡/复活)
## 承受伤害主入口
func take_damage(amount: int, attacker_type: CharacterType, _attacker_node: Node2D = null) -> void:
	# 1. 免疫判定
	if invincible or is_dead: return
	if attacker_type == character_type: return 
	
	# 2. 扣血
	if stats:
		stats.take_damage(float(amount))
		print("%s 受到伤害: %d | 剩余: %d" % [name, amount, stats.current_health])

	# 3. UI 更新
	if healthbar and stats: healthbar.value = stats.current_health
	
	# 4. 特效与死亡检查
	damage_effects()
	if stats and stats.current_health <= 0: _die()

## 死亡处理逻辑
func _die() -> void:
	if is_dead: return
	is_dead = true
	on_dead.emit()
	print("%s 已死亡" % name)
	
	# [核心修改 1] 如果死的是玩家，立即切断输入！
	if character_type == CharacterType.PLAYER:
		GameInputEvents.input_enabled = false
	
	# 1. 停止物理
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process(false)
	
	# 2. 暂时移除碰撞 (防止尸体挡路)
	collision_layer = 0
	collision_mask = 0
	var collider = get_node_or_null("CollisionShape2D")
	if collider: collider.set_deferred("disabled", true)
	
	# 3. 禁用侦查与UI
	if detection_Area: detection_Area.monitoring = false
	if healthbar: healthbar.visible = false
	if direction_Sign: direction_Sign.visible = false
	
	# 4. 播放死亡演出
	_play_mario_death_anim()

## 马里奥式死亡动画 (弹起后坠落)
func _play_mario_death_anim() -> void:
	if not sprite: return
	
	z_index = 100 # 确保在最上层
	sprite.stop()
	sprite.modulate = Color(0.8, 0.8, 0.8, 1.0) # 变灰
	
	var start_y = sprite.position.y
	var tween = create_tween()
	
	# 阶段1: 向上弹起
	tween.tween_property(sprite, "position:y", start_y - 60, 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# 阶段2: 加速坠落出屏幕
	tween.tween_property(sprite, "position:y", start_y + 1000, 1.0)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 敌人死亡后自动销毁
	if character_type == CharacterType.ENEMY:
		tween.tween_callback(queue_free)

## 重置角色状态 (复活/新关卡)
func reset_status() -> void:
	print(">>> [CharacterBase] 重置角色状态: ", name)
	
	# [核心修改 2] 如果是玩家复活，重新启用输入
	if character_type == CharacterType.PLAYER:
		GameInputEvents.input_enabled = true
	
	# 1. 状态复位
	is_dead = false
	invincible = false
	velocity = Vector2.ZERO
	z_index = 0
	
	# 2. 恢复逻辑与物理
	set_physics_process(true)
	set_process(true)
	
	# 3. [修复仇恨 Bug] 清空侦查列表和目标
	# 否则新的一天开始时，你可能还“盯着”上一局已经销毁的敌人
	enter_Character.clear()
	current_target = null
	current_tag = 0
	
	# 4. [关键] 恢复初始层级
	collision_layer = _initial_layer
	collision_mask = _initial_mask
	var collider = get_node_or_null("CollisionShape2D")
	if collider: collider.set_deferred("disabled", false)
	
	# 5. 恢复侦查
	if detection_Area: detection_Area.monitoring = true
	
	# 6. 视觉与数值复位
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
func _on_playerAttack_Area_body_entered(body: Node2D) -> void:
	print(">> [侦查] 有物体进入 %s 的视野: %s (Layer: %s)" % [name, body.name, body.collision_layer])
	if body is CharacterBase and target_types.has(body.character_type):
		var target: CharacterBase = body
		enter_Character.append(target)
		target.set_target_tag(enter_Character.size())
		print(">> [侦查] 锁定目标！")

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
	var overlapping_bodies: Array = detection_Area.get_overlapping_bodies()
	var closest_target: CharacterBase = null
	var closest_dist_sq: float = INF
	var self_pos: Vector2 = global_position
	
	for body in overlapping_bodies:
		if body is CharacterBase and body != self and target_types.has(body.character_type):
			if body.is_dead: continue # 忽略死人
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
		# 无目标时：根据移动方向显示箭头
		if velocity.length_squared() > 10.0:
			direction_Sign.rotation = velocity.angle()
			direction_Sign.visible = true
		else:
			direction_Sign.visible = false
#endregion

#region 视觉表现与辅助
## 根据水平速度翻转 Sprite
func Turn() -> void:
	if not sprite: return
	var default_facing = -1 if flipped_horizontal else 1
	if velocity.x < -0.1: sprite.scale.x = -default_facing
	elif velocity.x > 0.1: sprite.scale.x = default_facing

## 受伤闪白特效
func damage_effects() -> void:
	invincible = true
	if hit_particles: hit_particles.emitting = true
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10), 0.1) 
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	await tween.finished
	invincible = false

## 占位：如果有额外死亡特效可在此扩展
func die_effects() -> void:
	pass

func _on_health_changed(current, _max_val) -> void:
	if healthbar: healthbar.value = current

## 击退力计算
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
