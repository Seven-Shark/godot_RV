extends CharacterBody2D
class_name CharacterBase

## 角色基础类 (CharacterBase)
##
## 用于管理游戏中所有可移动/可交互角色的通用行为，包括：
## 1. 基础属性与阵营管理 (CharacterType)
## 2. 侦查系统 (Target Logic & Area2D)
## 3. 战斗系统 (Damage, Knockback, Death)
## 4. 视觉表现 (Flip, Effects, UI Sync)

#region 1. 信号定义
signal on_dead ## 当角色死亡时发出此信号
#endregion

#region 2. 枚举定义
## 场景上所有物件的阵营/类型枚举
enum CharacterType {
	ITEM,   ## 物品/箱子 (中立)
	PLAYER, ## 玩家 (友方)
	ENEMY   ## 敌人 (敌对)
}
#endregion

#region 3. 基础配置变量
@export_group("Base Settings")
@export var character_type: CharacterType = CharacterType.ITEM ## 当前角色的阵营/类型
@export var target_types: Array[CharacterType] = []            ## 侦查列表：该角色会把哪些类型视为目标
@export var flipped_horizontal: bool = false                   ## 图片朝向修正 (勾选=默认朝左, 未勾选=默认朝右)
@export var health: int = 100                                  ## [展示用] 实际血量逻辑建议参考 StatsComponent
#endregion

#region 4. 节点引用
@export_group("References")
@export var sprite: AnimatedSprite2D             ## 核心动画精灵
@export var healthbar: ProgressBar               ## 头部血条
@export var hit_particles: GPUParticles2D        ## 受击粒子特效节点
#endregion

#region 5. 物理参数
@export_group("Physics")
@export var knockback_friction: float = 1000.0   ## 击退摩擦力 (数值越大停得越快)
#endregion

#region 6. 内部状态变量
# --- 状态标志 ---
var invincible: bool = false                     ## [内部] 无敌状态标记
var is_dead: bool = false                        ## [内部] 死亡标记
var current_tag: int = 0                         ## [内部] 索敌排序ID

# --- 侦查与索敌 ---
var current_target: CharacterBase = null         ## [内部] 当前锁定的最近目标
var enter_Character: Array[CharacterBase] = []   ## [内部] 侦查区域内的有效对象列表

# --- 物理计算 ---
var knockback_velocity: Vector2 = Vector2.ZERO   ## [内部] 击退速度向量 (随时间衰减)
#endregion

#region 7. 节点获取 (OnReady)
@onready var detection_Area: Area2D = $DetectionArea                    ## 侦查区域
@onready var direction_Sign: Node2D = get_node_or_null("DirectionSign") ## 指示箭头
@onready var stats: StatsComponent = get_node_or_null("StatsComponent") ## 属性组件
#endregion

#region 生命周期
func _ready() -> void:
	# 1. 初始化侦查区域信号连接
	if detection_Area:
		detection_Area.body_entered.connect(_on_playerAttack_Area_body_entered)
		detection_Area.body_exited.connect(_on_playerAttack_Area_body_exited)
	
	# 2. 初始化血条与数值组件连接
	if stats and healthbar:
		healthbar.max_value = stats.max_health
		healthbar.value = stats.current_health
		# 连接组件信号以自动刷新 UI
		stats.health_changed.connect(_on_health_changed)
		stats.died.connect(_die)

func _physics_process(delta: float) -> void:
	# 处理击退速度的物理衰减
	_handle_knockback(delta)
	
	# 子类应在自己的 _physics_process 中调用 move_and_slide()
#endregion

#region 战斗逻辑 (伤害/击退/死亡)
## 承受伤害的主入口函数
## [param amount]: 伤害数值
## [param attacker_type]: 攻击者类型 (防止友军伤害)
## [param attacker_node]: (可选) 攻击者节点引用，用于计算受力方向
func take_damage(amount: int, attacker_type: CharacterType, _attacker_node: Node2D = null) -> void:
	# 1. 免疫判定：无敌、死亡或友军伤害
	if invincible or is_dead: return
	if attacker_type == character_type: return 
	
	# 2. 扣除血量 (通过组件)
	if stats:
		stats.take_damage(float(amount))
		print("%s 受到伤害: %d | 剩余: %d" % [name, amount, stats.current_health])
	else:
		print("%s [警告] 缺少 StatsComponent，无法扣血" % name)

	# 3. 刷新 UI 保底
	if healthbar and stats:
		healthbar.value = stats.current_health
	
	# 4. 播放特效
	damage_effects()
	
	# 5. 死亡判定 (组件通常会发 died 信号，此处为逻辑补充)
	if stats and stats.current_health <= 0:
		_die()

## 死亡处理逻辑
func _die() -> void:
	if is_dead: return
	is_dead = true
	
	on_dead.emit()
	print("%s 已死亡" % name)
	
	die_effects()
	
	# 根据类型处理后续逻辑
	if character_type == CharacterType.ENEMY:
		# 敌人：禁用碰撞，延迟销毁
		var collider = get_node_or_null("CollisionShape2D")
		if collider: collider.set_deferred("disabled", true)
		await get_tree().create_timer(1.0).timeout
		queue_free()
		
	elif character_type == CharacterType.PLAYER:
		# 玩家：进入游戏结束流程 (GameManager接管)
		print("玩家死亡，等待复活或结算...")

## 施加击退力
## [param direction]: 击退方向 (归一化向量)
## [param force]: 击退力度基础值
func apply_knockback(direction: Vector2, force: float) -> void:
	# 1. 获取重量 (默认 1.0)
	var weight = 1.0
	if stats and "max_weight" in stats:
		weight = max(1.0, stats.max_weight)
	
	# 2. 计算实际击退速度 (重量越大受力越小)
	# 系数 0.1 用于调整手感，避免高重量敌人完全不动
	var weight_factor = weight * 0.1 
	var final_knockback_speed = force / max(0.1, weight_factor)
	
	# 3. 应用速度
	knockback_velocity = direction * final_knockback_speed
	print("%s 被击退，速度: %.1f (重量: %.1f)" % [name, final_knockback_speed, weight])

## 处理击退速度衰减 (每帧调用)
func _handle_knockback(delta: float) -> void:
	if knockback_velocity.length_squared() > 1.0: # 稍微优化判断
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
	else:
		knockback_velocity = Vector2.ZERO
#endregion

#region 侦查与索敌逻辑a
## 区域进入回调
func _on_playerAttack_Area_body_entered(body: Node2D) -> void:
	if body is CharacterBase and target_types.has(body.character_type):
		var target: CharacterBase = body
		
		enter_Character.append(target)
		var enter_ID = enter_Character.size()
		target.set_target_tag(enter_ID)
		
		print("%s 进入视野 | ID: %d" % [target.name, target.current_tag])

## 区域离开回调
func _on_playerAttack_Area_body_exited(body: Node2D) -> void:
	if body is CharacterBase and target_types.has(body.character_type):
		var target: CharacterBase = body

		var index = enter_Character.find(target)
		if index != -1:
			enter_Character.remove_at(index)
			print("%s 离开视野 | 原ID: %d" % [target.name, target.current_tag])

			_update_all_enter_Character()
			target.clear_target_tag()

## 重新排序列表中的 ID
func _update_all_enter_Character() -> void:
	for i in range(enter_Character.size()):
		var target: CharacterBase = enter_Character[i]
		target.set_target_tag(i + 1)

## 获取最近的有效目标
func get_closest_target() -> CharacterBase:
	var overlapping_bodies: Array = detection_Area.get_overlapping_bodies()
	
	var closest_target: CharacterBase = null
	var closest_dist_sq: float = INF
	var self_pos: Vector2 = global_position

	for body in overlapping_bodies:
		if body is CharacterBase and body != self and target_types.has(body.character_type):
			var target: CharacterBase = body
			# 存活检查：忽略死人
			if target.is_dead: continue
			
			var dist_sq = self_pos.distance_squared_to(target.global_position)

			if dist_sq < closest_dist_sq:
				closest_dist_sq = dist_sq
				closest_target = target

	return closest_target

## 更新指示箭头指向
func Target_Lock_On(target: CharacterBase) -> void:
	if not is_instance_valid(direction_Sign): return

	if target:
		var dir = target.global_position - global_position
		direction_Sign.rotation = dir.angle()
		direction_Sign.visible = true
	else:
		# 无目标：运动时指前方，静止时隐藏
		if velocity.length_squared() > 10.0:
			direction_Sign.rotation = velocity.angle()
			direction_Sign.visible = true
		else:
			direction_Sign.visible = false
#endregion

#region 视觉表现与辅助
## 根据速度方向翻转 Sprite
func Turn() -> void:
	if not sprite: return
	var default_facing = -1 if flipped_horizontal else 1
	
	# 只在有明显横向移动时翻转
	if velocity.x < -0.1:
		sprite.scale.x = -default_facing
	elif velocity.x > 0.1:
		sprite.scale.x = default_facing

## 受伤视觉反馈
func damage_effects() -> void:
	invincible = true
	
	if hit_particles: hit_particles.emitting = true
	
	# 简单的闪白效果
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10), 0.1) 
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	await tween.finished
	invincible = false

## 死亡特效 (占位)
func die_effects() -> void:
	pass

## 血条更新回调
func _on_health_changed(current, _max_val) -> void:
	if healthbar: healthbar.value = current

## 设置索敌 ID
func set_target_tag(tag: int) -> void:
	current_tag = tag

## 清除索敌 ID
func clear_target_tag() -> void:
	current_tag = 0
#endregion
