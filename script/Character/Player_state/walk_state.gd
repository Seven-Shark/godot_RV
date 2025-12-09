@icon("res://Resource/Icon/StateSprite.png")
extends NodeState

@export var player:CharacterBody2D
@export var animated_sprite_2d:AnimatedSprite2D
@export var player_speed:float = 200.0



func _on_enter() -> void:
	animated_sprite_2d.play("Walk")

func _on_process(_delta : float) -> void:
	pass


func _on_physics_process(_delta : float) -> void:

	#if GameInputEvents.is_dash_input() == false:
		if GameInputEvents.is_movement_input():
			player.velocity = GameInputEvents.movement_input() * player_speed
			player.move_and_slide()
		
func _on_next_transitions() -> void:

	if GameInputEvents.is_movement_input() == false:
		transition.emit("Idle")
	if GameInputEvents.is_dash_input() == true:
		transition.emit("Dash")

func _on_exit() -> void:
	pass
