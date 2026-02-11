@icon("res://Resource/Icon/StateSprite.png")
extends NodeState
class_name AttackState

## 攻击状态 (AttackState)
## 职责：处理攻击动画播放、定身逻辑以及移动取消攻击(Animation Cancel)

@export var player: CharacterBody2D
@export var animated_sprite_2d: AnimatedSprite2D

func _on_enter() -> void:
	animated_sprite_2d.play("Attack")
	
	if player:
		player.velocity = Vector2.ZERO

func _on_process(_delta : float) -> void:
	pass

func _on_physics_process(delta : float) -> void:
	# [核心修复] 必须先读取输入！
	# 否则 GameInputEvents.is_movement_input() 拿到的永远是旧数据 (0,0)
	GameInputEvents.movement_input()

	# 增加高摩擦力，防止攻击时滑步
	if player:
		player.velocity = player.velocity.move_toward(Vector2.ZERO, 1000 * delta)
		player.move_and_slide()

func _on_next_transitions() -> void:
	# 逻辑 1: 移动打断 (Animation Cancel)
	# 现在这里能正确读到输入了，一旦按下方向键，就会立刻切换
	if GameInputEvents.is_movement_input():
		transition.emit("Walk")
		return

	# 逻辑 2: 冲刺打断
	if GameInputEvents.is_dash_input():
		transition.emit("Dash")
		return

	# 逻辑 3: 动画播放完毕自动回 Idle
	if not animated_sprite_2d.is_playing() or animated_sprite_2d.animation != "Attack":
		transition.emit("Idle")

func _on_exit() -> void:
	pass
