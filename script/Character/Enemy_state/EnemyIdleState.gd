@icon("res://Resource/Icon/StateSprite.png")
extends NodeState
class_name EnemyIdleState

@export var enemy: Enemy
@export var anim: AnimatedSprite2D

func _on_enter() -> void:
	anim.play("Idle")
	# 进入待机时，将速度归零
	enemy.velocity = Vector2.ZERO

func _on_physics_process(_delta: float) -> void:
	# 持续减速以防滑行
	enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, 10.0)

func _on_next_transitions() -> void:
	# 状态切换逻辑：如果触发了仇恨 -> 切换到追逐
	if enemy.is_aggro_active:
		transition.emit("Chase")
