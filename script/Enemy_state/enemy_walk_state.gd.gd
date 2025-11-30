@icon("res://Resource/Icon/StateSprite.png")
extends NodeState

@export var enemy_1:CharacterBody2D
@export var animated_Sprite_2d:AnimatedSprite2D
@export var enemy_1_Speed:float = 200.0



func _on_enter() -> void:
	animated_Sprite_2d.play("Walk")

func _on_process(_delta : float) -> void:
	pass


func _on_physics_process(_delta : float) -> void:
	pass

func _on_next_transitions() -> void:
	pass

func _on_exit() -> void:
	pass
