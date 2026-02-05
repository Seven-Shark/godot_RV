@icon("res://Resource/Icon/StateSprite.png")
extends NodeState
class_name EnemyCooldownState

@export var enemy: Enemy
@export var anim: AnimatedSprite2D

var timer: float = 0.0

func _on_enter() -> void:
	enemy.velocity = Vector2.ZERO
	anim.play("Idle")
	timer = enemy.attack_cooldown # 读取配置

func _on_process(delta: float) -> void:
	timer -= delta

func _on_next_transitions() -> void:
	if timer <= 0:
		# 冷却结束，根据仇恨决定去向
		if enemy.is_aggro_active:
			transition.emit("chase")
		else:
			transition.emit("idle")
