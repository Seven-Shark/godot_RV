@icon("res://Resource/Icon/StateSprite.png")
extends NodeState
class_name AttackState

@export var player: CharacterBody2D
@export var player_stats: CharacterBase
@export var animated_sprite_2d: AnimatedSprite2D

func _on_enter() -> void:
	animated_sprite_2d.play("Attack")
	player.velocity = Vector2.ZERO

func _on_process(_delta: float) -> void:
	pass

func _on_physics_process(delta: float) -> void:
	# 增加高摩擦力，防止攻击时还能滑步 (除非被击退)
	# 这里的 1000 是摩擦力数值，可以按需调整
	player.velocity = player.velocity.move_toward(Vector2.ZERO, 1000 * delta)
	player.move_and_slide()

func _on_next_transitions() -> void:
	# 1. 移动取消 (Animation Cancel)
	if GameInputEvents.is_movement_input():
		transition.emit("Walk")
		return

	# 2. 冲刺取消
	if GameInputEvents.is_dash_input():
		var stats = player_stats.stats as CharacterStatsComponent
		if stats and stats.can_use_dash():
			transition.emit("Dash")
			return

	# 3. 动画自然结束 -> Idle
	# (注意：如果不加这个，攻击完会卡住；也可以用 AnimationPlayer 的 signal)
	if not animated_sprite_2d.is_playing() or animated_sprite_2d.animation != "Attack":
		transition.emit("Idle")

func _on_exit() -> void:
	pass
