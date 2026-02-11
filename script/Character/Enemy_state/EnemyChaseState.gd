@icon("res://Resource/Icon/StateSprite.png")
extends EnemyState
class_name EnemyChaseState

@export var move_speed: float = 100.0

func enter() -> void:
	anim.play("Walk") # 请确保你的动画机里有 Walk 或者 Run

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
	
	var final_speed = move_speed
	if enemy.stats:
		final_speed = enemy.stats.get_final_speed(false, delta)

	# 三段式位移
	if dist > enemy.attack_distance:
		enemy.velocity = dir * final_speed
	elif dist < enemy.retreat_distance:
		enemy.velocity = -dir * final_speed * 0.8
	else:
		enemy.velocity = Vector2.ZERO

func _on_next_transitions() -> void:
	if not enemy.is_aggro_active:
		transition.emit("Idle")
		return
	
	if is_instance_valid(enemy.current_target):
		var dist = enemy.global_position.distance_to(enemy.current_target.global_position)
		if dist <= enemy.attack_distance:
			transition.emit("Attack")
