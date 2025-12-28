extends CharacterBody2D
class_name CharacterBase

#定义场景上所有物件的类型
enum CharacterType{
	ITEM,
	PLAYER,
	ENEMY
}
@export var character_type:CharacterType = CharacterType.ITEM



@export var sprite : AnimatedSprite2D
@export var healthbar : ProgressBar
@export var health : int
@export var flipped_horizontal : bool
@export var hit_particles : GPUParticles2D
var invincible : bool = false
var is_dead : bool = false
var current_tag: int = 0 #当前被分配的ID


#定义一个侦查区的变量
@onready var detection_Area = $DetectionArea
#定义一个判断敌人方位的箭头
@onready var direction_Sign = get_node_or_null("DirectionSign")
#定义当前距离最近的敌人对象
var current_target : CharacterBase = null
#定义一个列表，存储当前进入侦查区内的所有对象
var enter_Character : Array[CharacterBase] = []
#定义一个列表，存储当前侦查区内所有对象的类型
@export var target_types: Array[CharacterType] = []


signal on_dead


func _ready():
	var playerAttack_Area = $DetectionArea
	playerAttack_Area.body_entered.connect(_on_playerAttack_Area_body_entered)
	playerAttack_Area.body_exited.connect(_on_playerAttack_Area_body_exited)
	
	if healthbar:
		healthbar.max_value = health
		healthbar.value = health


#func init_character():
	#healthbar.max_value = health
	#healthbar.value = health

#根据角色移动方向翻转角色图片
func Turn():
	var direction = -1 if flipped_horizontal  else 1
	if(velocity.x < 0):
		sprite.scale.x = -direction
	elif(velocity.x > 0):
		sprite.scale.x = direction


#判断进入侦查区域的对象
func _on_playerAttack_Area_body_entered(body: Node2D):

	#判断是不是敌人
	if body is CharacterBase and target_types.has(body.character_type):
		var object_Character : CharacterBase = body
		#将敌人加入对象组
		enter_Character.append(object_Character)
		#打上进入标签
		var enter_ID = enter_Character.size()
		object_Character.set_target_tag(enter_ID)
		print(object_Character.name ,"进入区域" +"    "+"ID：" ,object_Character.current_tag)

#判断离开入侦查区域的对象
func _on_playerAttack_Area_body_exited(body: Node2D):

	#判断是不是敌人
	if body is CharacterBase and target_types.has(body.character_type):
		var object_Character : CharacterBase = body

		#是的话找到他在数组中的位置，然后删除
		var index = enter_Character.find(object_Character)
		if index != -1:
			var original_tag = index + 1
			#移除
			enter_Character.remove_at(index)
			print(object_Character.name,"离开区域","    ","ID：",object_Character.current_tag )

			#重新对所有剩余目标打标签，并自动补位
			_update_all_enter_Character()

			#通知离开的对象清除ID
			object_Character.clear_target_tag()

#对所有剩余的对象进行重新的标签排序
func _update_all_enter_Character():
	for i in range(enter_Character.size()):
		var target: CharacterBase = enter_Character[i]
		var new_tag = i + 1
		# 傳遞新的 ID
		target.set_target_tag(new_tag)

#用于判断距离角色最近的对象
#1、记录进入角色判定范围内的对象实时距离的
#2、距离最近的对象视为“目标者”
#3、距离相同的话，优先锁定前者
#4、实时更新
func get_closest_target() -> CharacterBase:

	#获取需要识别的对象类型
	var need_target_type = target_types

	# 1、获取侦测区域内重叠的所有 Body 对象
	var overlapping_bodies:Array = detection_Area.get_overlapping_bodies()
	var closest_target: CharacterBase = null
	var closest_distance_sq:float = INF

	# 2、获取当前角色的位置（作为距离的起点）
	var self_position:Vector2 = global_position

	# 3、遍历所有重叠的物体
	for body in overlapping_bodies:
		#判断目标对象是characterbase、不是自己、并且在对象池子里面
		if body is CharacterBase and body != self and need_target_type.has(body.character_type):
			var target:CharacterBase = body

			#4、计算距离的平方
			var distance_sq = self_position.distance_squared_to(target.global_position)

			#5、比较并更新最近的目标
			if distance_sq < closest_distance_sq:
				closest_distance_sq = distance_sq
				closest_target = target

	return closest_target

#用于旋转箭头指向距离自己最近的对象
func Target_Lock_On(target: CharacterBase):

	if is_instance_valid(direction_Sign):

		if target:
			# 1、计算方向向量 (目标位置 - 自身位置)
			var direction_vector:Vector2 = target.global_position - global_position
			# 2、将方向向量转换为旋转角度（弧度）
			var target_rotation:float = direction_vector.angle()
			# 3、应用并旋转角度
			direction_Sign.rotation = target_rotation
			direction_Sign.visible = true
		else:
			#判断当前是否有速度（防止静止时箭头归零或乱转）
			if velocity.length_squared() > 10.0:
				direction_Sign.rotation = velocity.angle()
				direction_Sign.visible = true
				
			else:
				#没有目标的时候隐藏
				direction_Sign.visible = false
			
			
#用于判断受伤的逻辑
func take_damage(amount:int,attacker_type:CharacterType) -> void:
	
	#如果无敌或者已经死了则跳过
	if invincible or is_dead:
		return
	
	#友军伤害免疫（可选）
	if attacker_type == character_type:
		return
	
	#扣血逻辑
	health -= amount
	print(name + "受到伤害：" + str(amount) + "————剩余血量：" +str(health))
	
	if healthbar:
		healthbar.value = health
	
	#受伤表现
	damage_effects()
	
	#死亡判定
	if health <= 0:
		_die()

#受伤效果：无敌帧、特效
func damage_effects():
	invincible = true
	
	if hit_particles:
		hit_particles.emitting = true
	# 颜色闪烁 (Godot 4 Tween 写法)
	var tween = create_tween()
	# 变红 -> 变回原色 -> 变红 -> 变回原色
	tween.tween_property(sprite, "modulate", Color(10, 10, 10), 0.1) # 甚至可以高亮变白
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	await tween.finished
	
	invincible = false


#死亡逻辑
func _die():
	if is_dead:return
	is_dead = true
	on_dead.emit()
	print(name + "已死亡")
	
	#播放死亡特效
	die_effects()

# 如果是敌人，延迟销毁；如果是玩家，可能需要处理游戏结束逻辑
	if character_type == CharacterType.ENEMY:
		# 禁用碰撞防止诈尸
		$CollisionShape2D.set_deferred("disabled", true) 
		await get_tree().create_timer(1.0).timeout
		queue_free()
	elif character_type == CharacterType.PLAYER:
		print("玩家死亡，游戏结束流程...")
		# 不要 destroy 玩家，通常是弹窗重开

#死亡特效，暂未启用
func die_effects():
	pass

# 设置标签（父类通用方法）
func set_target_tag(tag: int) -> void:
	current_tag = tag
	# print(name + " 被标记为 ID: " + str(tag)) # 调试用

# 清除标签（父类通用方法）
func clear_target_tag() -> void:
	current_tag = 0

#region Taking Damage

#Play universal damage sound effect for any character taking damage and flashing red
#func damage_effects():
	##AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, -3)
	#after_damage_iframes()
	#if(hit_particles):
		#hit_particles.emitting = true
#
##After we are done flashing red, we can take damage again
#func after_damage_iframes():
	#invincible = true
	#var tween = create_tween()
	#tween.tween_property(self, "modulate", Color.DARK_RED, 0.1)
	#tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	#tween.tween_property(self, "modulate", Color.RED, 0.1)
	#tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	#await tween.finished
	#invincible = false
	#
#func _take_damage(amount):
	#if(invincible == true || is_dead == true):
		#return
		#
	#health -= amount
	#healthbar.value = health;
	#damage_effects()
	#
	#if(health <= 0):
		#_die()
		#
#func _die():
	#if(is_dead):
		#return
		#
	#is_dead = true
	##Remove/destroy this character once it's able to do so unless its the player
	#await get_tree().create_timer(1.0).timeout
	#if is_instance_valid(self) and not is_in_group("Player"):
		#queue_free()
#endregion
