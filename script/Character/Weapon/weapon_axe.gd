extends Node2D


@onready var anim = $AnimationPlayer


func play_idle():
	anim.play("Axe_Idle")
	
func play_attack():
	anim.play("Axe_Attack")
