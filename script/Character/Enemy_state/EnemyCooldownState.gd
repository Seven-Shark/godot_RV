@icon("res://Resource/Icon/StateSprite.png")
extends EnemyState
class_name EnemyCooldownState

var timer: float = 0.0

func enter() -> void:
	enemy.velocity = Vector2.ZERO
	anim.play("Idle")
	timer = enemy.attack_cooldown # 读取 Enemy 配置的冷却时间

func _on_process(delta: float) -> void:
	timer -= delta

func _on_next_transitions() -> void:
	if timer <= 0:
		if enemy.is_aggro_active:
			transition.emit("Chase")
		else:
			transition.emit("Idle")
