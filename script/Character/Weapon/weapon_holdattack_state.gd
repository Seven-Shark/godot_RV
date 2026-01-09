@icon("res://Resource/Icon/StateSprite.png")
extends NodeState

@export var weapon_admin: WeaponAdmin

func _on_enter() -> void:
	# 1. 播放开始动画
	if weapon_admin.current_weapon.has_method("play_holdattack"):
		weapon_admin.current_weapon.play_holdattack()

func _on_process(_delta : float) -> void:
	pass

func _on_physics_process(delta : float) -> void:
	# 【核心逻辑接管】
	# 只要在这个状态里，就每一帧驱动武器执行引力逻辑
	var current_weapon = weapon_admin.current_weapon
	if current_weapon and current_weapon.has_method("process_gravity_tick"):
		current_weapon.process_gravity_tick(delta)

func _on_next_transitions() -> void:
	# 检查松手逻辑
	# 如果是引力枪，且右键不再按住，则切回 Idle
	if "Weapon_Gravitation" in weapon_admin.current_weapon.name:
		if not GameInputEvents.is_special_attack_held(): # 假设这是 Input.is_mouse_button_pressed(RIGHT)
			transition.emit("weapon_idle")

func _on_exit() -> void:
	# 状态退出时，强制停止引力波
	if weapon_admin.current_weapon.has_method("stop_gravity_firing"):
		weapon_admin.current_weapon.stop_gravity_firing()
	elif weapon_admin.current_weapon.has_method("play_idle"):
		weapon_admin.current_weapon.play_idle()
