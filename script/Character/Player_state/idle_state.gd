@icon("res://Resource/Icon/StateSprite.png")
extends NodeState

@export var player: CharacterBody2D
@export var player_stats: CharacterBase ## 必须引用 CharacterBase 才能拿到 Stats
@export var animated_sprite_2d: AnimatedSprite2D

func _on_enter() -> void:
	animated_sprite_2d.play("Idle")
	player.velocity = Vector2.ZERO

func _on_process(_delta: float) -> void:
	pass

func _on_physics_process(_delta: float) -> void:
	# 待机时也要 move_and_slide，否则被敌人撞击击退时会卡住
	player.move_and_slide()

func _on_next_transitions() -> void:
	# 1. 移动
	if GameInputEvents.is_movement_input():
		transition.emit("Walk")
		return
	
	# 2. 攻击
	if GameInputEvents.is_main_attack_just_pressed():
		transition.emit("Attack")
		return

	# 3. 冲刺 (结合 Stats 判断)
	if GameInputEvents.is_dash_input():
		var stats = player_stats.stats as CharacterStatsComponent
		# [关键] 只有 Stats 说能冲，才允许切换
		if stats and stats.can_use_dash():
			transition.emit("Dash")

func _on_exit() -> void:
	pass
