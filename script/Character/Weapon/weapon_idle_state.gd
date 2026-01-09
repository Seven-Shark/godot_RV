@icon("res://Resource/Icon/StateSprite.png")

extends NodeState

@export var weapon_admin: WeaponAdmin


func _on_enter() -> void:

	# 进入状态时，让管理器播放当前武器的 Idle
	if weapon_admin and weapon_admin.current_weapon and weapon_admin.current_weapon.visible:
		if weapon_admin.current_weapon.has_method("play_idle"):
			weapon_admin.current_weapon.play_idle()

func _on_process(_delta : float) -> void:
	pass


func _on_physics_process(_delta : float) -> void:
	pass

func _on_next_transitions() -> void:
	if not weapon_admin.current_weapon:
		return
	# 1. 检查引力枪 (持续攻击)
	if "Weapon_Gravitation" in weapon_admin.current_weapon.name:
		# 【修改】：使用 GameInputEvents 检测右键按住
		if GameInputEvents.is_special_attack_held():
			transition.emit("weapon_holdattack")
			print("引力攻击")
			return
		# 2. 检查普通攻击 (单次)
		# 【修改】：使用 GameInputEvents 检测左键点击
		elif GameInputEvents.is_main_attack_held():
			transition.emit("weapon_attack")
			print("震荡波")
			return
			
	#if GameInputEvents.attack_input() :
		#transition.emit("weapon_attack")
		#print("攻击")

func _on_exit() -> void:
	pass
