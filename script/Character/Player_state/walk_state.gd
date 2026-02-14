@icon("res://Resource/Icon/StateSprite.png")
extends NodeState

@export var player: CharacterBody2D
@export var player_stats: CharacterBase
@export var animated_sprite_2d: AnimatedSprite2D

func _on_enter() -> void:
	animated_sprite_2d.play("Walk")

func _on_process(_delta: float) -> void:
	pass

func _on_physics_process(_delta: float) -> void:
	# 即使没有输入，也要持续运行物理，防止惯性滑行不自然
	if player_stats.stats:
		var stats = player_stats.stats as CharacterStatsComponent
		var dir = GameInputEvents.movement_input()
		
		# 使用 Stats 组件里的基础速度
		player.velocity = dir * stats.base_walk_speed
		player.move_and_slide()

func _on_next_transitions() -> void:
	# 1. 停止移动 -> Idle
	if not GameInputEvents.is_movement_input():
		transition.emit("Idle")
		return
	
	# 2. 攻击打断
	if GameInputEvents.is_main_attack_just_pressed():
		transition.emit("Attack")
		return

	# 3. 冲刺打断
	if GameInputEvents.is_dash_input():
		var stats = player_stats.stats as CharacterStatsComponent
		if stats and stats.can_use_dash():
			transition.emit("Dash")

func _on_exit() -> void:
	pass
