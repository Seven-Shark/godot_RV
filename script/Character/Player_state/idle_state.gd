@icon("res://Resource/Icon/StateSprite.png")

extends NodeState

@export var player:CharacterBody2D
@export var animated_Sprite_2d:AnimatedSprite2D

var moving_right : bool = true


func _on_enter() -> void:
	animated_Sprite_2d.play("Idle")

func _on_process(_delta : float) -> void:
	pass

func _on_physics_process(_delta : float) -> void:
	GameInputEvents.movement_input()

func _on_next_transitions() -> void:
	GameInputEvents.is_movement_input()

	if GameInputEvents.is_movement_input() == true:
		transition.emit("Walk")

		
func _on_exit() -> void:
	pass
