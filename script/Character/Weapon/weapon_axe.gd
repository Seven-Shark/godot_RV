extends Node2D


@onready var anim = $AnimationPlayer

signal weapon_finished

func play_idle():
	anim.play("Axe_Idle")
	
func play_attack():
	anim.play("Axe_Attack")

func finish_action():
	weapon_finished.emit()
