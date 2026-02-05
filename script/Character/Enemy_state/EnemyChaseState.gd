@icon("res://Resource/Icon/StateSprite.png")
extends NodeState
class_name EnemyChaseState

@export var enemy: Enemy
@export var anim: AnimatedSprite2D
@export var move_speed: float = 100.0

func _on_enter() -> void:
	anim.play("Walk")

func _on_physics_process(delta: float) -> void:
	if not is_instance_valid(enemy.current_target):
		enemy.velocity = Vector2.ZERO
		return

	# 1. 转身
	enemy.face_current_target()
	
	# 2. 移动逻辑
	var to_target = enemy.current_target.global_position - enemy.global_position
	var dist = to_target.length()
	var dir = to_target.normalized()
	
	# 获取最终速度 (包含减速buff等)
	var final_speed = move_speed
	if enemy.stats:
		final_speed = enemy.stats.get_final_speed(false, delta)

	# 三段式位移
	if dist > enemy.attack_distance:
		enemy.velocity = dir * final_speed
	elif dist < enemy.retreat_distance:
		enemy.velocity = -dir * final_speed * 0.8
	else:
		# 在攻击范围内，停车
		enemy.velocity = Vector2.ZERO

func _on_next_transitions() -> void:
	# 1. 没仇恨了 -> 待机
	if not enemy.is_aggro_active:
		transition.emit("idle")
		return
	
	# 2. 距离够近 -> 攻击
	if is_instance_valid(enemy.current_target):
		var dist = enemy.global_position.distance_to(enemy.current_target.global_position)
		if dist <= enemy.attack_distance:
			transition.emit("attack")
