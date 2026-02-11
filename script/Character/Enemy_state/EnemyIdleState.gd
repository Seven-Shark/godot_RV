@icon("res://Resource/Icon/StateSprite.png")
extends EnemyState
class_name EnemyIdleState

func enter() -> void:
	anim.play("Idle")
	enemy.velocity = Vector2.ZERO

func _on_physics_process(_delta: float) -> void:
	# 摩擦力停车
	enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, 10.0)

func _on_next_transitions() -> void:
	if enemy.is_aggro_active:
		transition.emit("Chase")
		
