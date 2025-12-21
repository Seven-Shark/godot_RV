@icon("res://Resource/Icon/StateSprite.png")

extends NodeState

@export var weapon_admin: WeaponAdmin


func _on_enter() -> void:

	# 进入状态时，让管理器播放当前武器的 Idle
	if weapon_admin and weapon_admin.current_weapon and weapon_admin.current_weapon.visible:
		weapon_admin.current_weapon.play_idle()

func _on_process(_delta : float) -> void:
	# 监听攻击输入
	GameInputEvents.attack_input()


func _on_physics_process(_delta : float) -> void:
	pass

func _on_next_transitions() -> void:
	if GameInputEvents.attack_input() :
		transition.emit("weapon_attack")
		print("攻击")

func _on_exit() -> void:
	pass
