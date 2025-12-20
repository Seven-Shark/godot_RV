extends Node2D


@onready var animation_player = $AnimationPlayer

func play_idle():
	print("Sword Idle")
	
func play_attack():
	print("Sword Attack")
