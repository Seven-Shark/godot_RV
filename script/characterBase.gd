extends CharacterBody2D
class_name CharacterBase


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

@onready var detection_Area = $DetectionArea



#func _ready():
	#init_character()
	
	
#Add anything here that needs to be initialized on the character
#func init_character():
	#healthbar.max_value = health
	#healthbar.value = health

#根据角色移动方向翻转角色图片
func Turn():
	#This ternary lets us flip a sprite if its drawn the wrong way
	var direction = -1 if flipped_horizontal == true else 1

	if(velocity.x < 0):
		sprite.scale.x = -direction
	elif(velocity.x > 0):
		sprite.scale.x = direction

#用于判断距离角色最近的对象
#1、记录进入角色判定范围内的对象实时距离的
#2、距离最近的对象视为“目标者”
#3、距离相同的话，优先锁定前者
#4、实时更新
func get_closest_target() -> CharacterBase:

	# 1、获取侦测区域内重叠的所有 Body 对象
	var overlapping_bodies:Array = detection_Area.get_overlapping_bodies()
	var closest_target: CharacterBase = null
	var closest_distance_sq:float = INF

	# 2、获取当前角色的位置（作为距离的起点）
	var self_position:Vector2 = global_position

	# 3、遍历所有重叠的物体
	for body in overlapping_bodies:
		if body is CharacterBase and body != self:
			var target:CharacterBase = body

			#4、计算距离的平方
			var distance_sq = self_position.distance_squared_to(target.global_position)

			#5、比较并更新最近的目标
			if distance_sq < closest_distance_sq:
				closest_distance_sq = distance_sq
				closest_target = target

	return closest_target

	





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
