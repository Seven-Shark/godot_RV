@icon("res://Resource/Icon/StateSprite.png")

extends NodeState
@export var weapon_admin: WeaponAdmin


func _on_enter() -> void:
	if weapon_admin:
		# 1. 连接信号：当动作结束时切回 Idle
		# 为了防止重复连接，先断开（或者在 _ready 里连一次）
		if not weapon_admin.action_finished.is_connected(_on_attack_finished):
			weapon_admin.action_finished.connect(_on_attack_finished)
		
		# 2. 执行攻击
		weapon_admin.enter_attack_state()
func _on_attack_finished() -> void:
	# 攻击结束，切回待机状态
	transition.emit("weapon_idle")

func _on_process(_delta : float) -> void:
	pass

func _on_physics_process(_delta : float) -> void:
	pass
	
func _on_next_transitions() -> void:
	pass

func _on_exit() -> void:
	# 退出状态时，记得断开信号，是一个好习惯
	if weapon_admin and weapon_admin.action_finished.is_connected(_on_attack_finished):
		weapon_admin.action_finished.disconnect(_on_attack_finished)
