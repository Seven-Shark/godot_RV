extends CharacterBody2D
class_name CharacterBase

## 角色基础类
##
## 用于管理游戏中所有角色的通用行为，包括：
## 1. 基础属性（血量、类型）
## 2. 侦查系统（索敌、目标列表维护）
## 3. 战斗系统（受伤、死亡、击退物理计算）
## 4. 视觉表现（翻转、受伤特效、血条同步）


# 1. 信号定义
signal on_dead # 当角色死亡时发出此信号

# 2. 枚举与常量
# 定义场景上所有物件的类型
enum CharacterType {
	ITEM,   # 物品/箱子
	PLAYER, # 玩家
	ENEMY   # 敌人
}

# 3. 导出变量 (Inspector 配置)
#region 基础配置
@export_group("Base Settings")
@export var character_type: CharacterType = CharacterType.ITEM ## 当前角色的阵营/类型
@export var target_types: Array[CharacterType] = []            ## 侦查列表：该角色会把哪些类型视为敌人/目标
@export var flipped_horizontal: bool = false                   ## 图片朝向修正（勾选代表素材默认朝左，未勾选朝右）

# 注意：如果使用了 StatsComponent，这个 health 变量可能仅作展示或备用，
# 实际逻辑主要依赖 StatsComponent 的 current_health
@export var health: int 
#endregion

#region 节点引用
@export_group("References")
@export var sprite: AnimatedSprite2D     ## 核心动画精灵
@export var healthbar: ProgressBar       ## 头部血条
@export var hit_particles: GPUParticles2D ## 受击粒子特效节点
#endregion

#region 物理参数
@export_group("Physics")
@export var knockback_friction: float = 1000.0 ## 击退摩擦力（数值越大，被击退后停得越快）
#endregion


# 4. 内部变量
#region 状态标志
var invincible: bool = false ## 是否处于无敌状态
var is_dead: bool = false    ## 是否已经死亡
var current_tag: int = 0     ## 当前被分配的索敌ID（用于群体行为排序）
#endregion

#region 侦查与索敌
var current_target: CharacterBase = null     ## 当前锁定的最近目标
var enter_Character: Array[CharacterBase] = [] ## 存储当前进入侦查区内的所有有效对象
#endregion

#region 物理计算
var knockback_velocity: Vector2 = Vector2.ZERO ## 当前受到的击退速度向量（随时间衰减）
#endregion


# 5. 节点获取 (OnReady)
@onready var detection_Area = $DetectionArea                  ## 侦查区域 (Area2D)
@onready var direction_Sign = get_node_or_null("DirectionSign") ## 敌人方位指示箭头
@onready var stats: StatsComponent = get_node_or_null("StatsComponent") ## 属性数值组件


# 6. 生命周期方法
func _ready() -> void:
	# 1. 初始化侦查区域信号
	if detection_Area:
		detection_Area.body_entered.connect(_on_playerAttack_Area_body_entered)
		detection_Area.body_exited.connect(_on_playerAttack_Area_body_exited)
	
	# 2. 初始化血条与数值组件连接
	if stats and healthbar:
		healthbar.max_value = stats.max_health
		healthbar.value = stats.current_health
		# 连接信号：当组件血量变化时，自动刷新血条
		stats.health_changed.connect(_on_health_changed)
		stats.died.connect(_die)

func _physics_process(delta: float) -> void:
	# 处理击退速度的物理衰减
	_handle_knockback(delta)
	
	# 注意：子类 (如 Enemy.gd) 应该在自己的 _physics_process 中调用 move_and_slide()
	# 以应用 velocity (包含 knockback_velocity)

# 7. 战斗逻辑 (受伤、击退、死亡)
#region 受伤与死亡
## 承受伤害的主入口函数
## [param amount]: 伤害数值
## [param attacker_type]: 攻击者的类型（用于防止友军伤害）
## [param attacker_node]: 攻击者节点引用（可选，用于计算击退方向）
func take_damage(amount: int, attacker_type: CharacterType, _attacker_node: Node2D = null) -> void:
	# 1. 状态检查：如果无敌、已死或同阵营，则忽略伤害
	if invincible or is_dead:
		return
	if attacker_type == character_type:
		return # 友军伤害免疫
	
	# 2. 扣除血量 (通过组件)
	if stats:
		stats.take_damage(float(amount))
		print(name + " 受到伤害：" + str(amount) + " | 剩余血量：" + str(stats.current_health))
	else:
		print(name + " [警告] 没有 StatsComponent，可能是纯物理物件，建议直接销毁或做其他处理")

	# 3. 刷新血条显示 (双重保险，防止信号延迟)
	if healthbar and stats:
		healthbar.value = stats.current_health
	
	# 4. 播放受伤表现
	damage_effects()
	
	# 5. 死亡判定 (组件通常会发信号，这里作为逻辑补充)
	if stats and stats.current_health <= 0:
		_die()

## 死亡逻辑处理
func _die():
	if is_dead: return
	is_dead = true
	
	on_dead.emit()
	print(name + " 已死亡")
	
	# 播放死亡特效
	die_effects()
	
	# 根据类型处理后续逻辑
	if character_type == CharacterType.ENEMY:
		# 敌人：禁用碰撞，延迟销毁
		var collider = get_node_or_null("CollisionShape2D")
		if collider:
			collider.set_deferred("disabled", true)
		await get_tree().create_timer(1.0).timeout
		queue_free()
		
	elif character_type == CharacterType.PLAYER:
		# 玩家：通常由 GameManager 处理游戏结束，不直接销毁
		print("玩家死亡，进入游戏结束流程...")
#endregion

#region 击退系统
## 接收击退力
## [param direction]: 击退方向 (归一化向量)
## [param force]: 基础击退力度
func apply_knockback(direction: Vector2, force: float):
	# 1. 获取重量 (防止除以0)
	var weight = 1.0
	if stats:
		weight = max(1.0, stats.max_weight)
	
	# 2. 计算受力后的实际速度
	# 公式说明：重量越大，受到的击退越小
	# weight_factor 系数 0.1 用于调整手感，避免重型敌人完全推不动
	var weight_factor = weight * 0.1 
	var final_knockback_speed = force / max(0.1, weight_factor)
	
	# 3. 施加击退速度 (将在 _physics_process 中处理位移)
	knockback_velocity = direction * final_knockback_speed
	print(name + " 被击退，速度: " + str(final_knockback_speed) + " (重量: " + str(weight) + ")")

## 处理击退速度的衰减 (每帧调用)
func _handle_knockback(delta: float):
	if knockback_velocity.length() > 0:
		# 使用 move_toward 平滑地将速度归零，模拟摩擦力
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
#endregion

# 8. 侦查与索敌逻辑
#region 区域检测
## 当物体进入侦查区域
func _on_playerAttack_Area_body_entered(body: Node2D):
	# 判断进入者是否为 CharacterBase 且在目标类型列表中
	if body is CharacterBase and target_types.has(body.character_type):
		var object_Character: CharacterBase = body
		
		# 加入列表并分配 ID
		enter_Character.append(object_Character)
		var enter_ID = enter_Character.size()
		object_Character.set_target_tag(enter_ID)
		
		print(object_Character.name, " 进入区域 | ID：", object_Character.current_tag)

## 当物体离开侦查区域
func _on_playerAttack_Area_body_exited(body: Node2D):
	if body is CharacterBase and target_types.has(body.character_type):
		var object_Character: CharacterBase = body

		# 在列表中查找并移除
		var index = enter_Character.find(object_Character)
		if index != -1:
			enter_Character.remove_at(index)
			print(object_Character.name, " 离开区域 | 原ID：", object_Character.current_tag)

			# 重新排序剩余目标的 ID
			_update_all_enter_Character()

			# 清除离开者的标签
			object_Character.clear_target_tag()

## 更新侦查列表内所有对象的 ID (填补空缺)
func _update_all_enter_Character():
	for i in range(enter_Character.size()):
		var target: CharacterBase = enter_Character[i]
		var new_tag = i + 1
		target.set_target_tag(new_tag)
#endregion

#region 目标计算
## 获取距离最近的有效目标
## 返回: 最近的 CharacterBase 对象，如果没有则返回 null
func get_closest_target() -> CharacterBase:
	var need_target_type = target_types
	var overlapping_bodies: Array = detection_Area.get_overlapping_bodies()
	
	var closest_target: CharacterBase = null
	var closest_distance_sq: float = INF # 使用平方距离比较，性能更好
	var self_position: Vector2 = global_position

	for body in overlapping_bodies:
		# 筛选条件：必须是CharacterBase、不是自己、且是敌对类型
		if body is CharacterBase and body != self and need_target_type.has(body.character_type):
			var target: CharacterBase = body
			var distance_sq = self_position.distance_squared_to(target.global_position)

			# 更新最近目标
			if distance_sq < closest_distance_sq:
				closest_distance_sq = distance_sq
				closest_target = target

	return closest_target

## 旋转指示箭头指向目标
func Target_Lock_On(target: CharacterBase):
	if not is_instance_valid(direction_Sign):
		return

	if target:
		# 有目标：指向目标
		var direction_vector = target.global_position - global_position
		direction_Sign.rotation = direction_vector.angle()
		direction_Sign.visible = true
	else:
		# 无目标：如果正在移动，指向移动方向；静止则隐藏
		if velocity.length_squared() > 10.0:
			direction_Sign.rotation = velocity.angle()
			direction_Sign.visible = true
		else:
			direction_Sign.visible = false
#endregion

# 9. 视觉表现与辅助方法
#region 视觉特效
## 翻转角色图片 (根据移动方向)
func Turn():
	var direction = -1 if flipped_horizontal else 1
	if velocity.x < 0:
		sprite.scale.x = -direction
	elif velocity.x > 0:
		sprite.scale.x = direction

## 受伤视觉反馈 (闪烁、粒子)
func damage_effects():
	invincible = true # 开启短暂无敌帧
	
	if hit_particles:
		hit_particles.emitting = true
		
	# 颜色闪烁动画
	var tween = create_tween()
	# 变亮 -> 变红 -> 变回原色
	tween.tween_property(sprite, "modulate", Color(10, 10, 10), 0.1) 
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	await tween.finished
	invincible = false

## 死亡特效 (预留接口)
func die_effects():
	pass

## UI回调：当属性组件血量变化时调用
func _on_health_changed(current, _max_val):
	if healthbar:
		healthbar.value = current
#endregion

#region 标签管理
## 设置当前目标的 ID 标签
func set_target_tag(tag: int) -> void:
	current_tag = tag

## 清除标签
func clear_target_tag() -> void:
	current_tag = 0
#endregion
