@icon("res://Resource/Icon/StateSprite.png")

extends NodeState
@export var weapon_admin: WeaponAdmin

var _is_animation_finished := false


func _on_enter() -> void:
	_is_animation_finished = false
	# 连接信号：当动画结束时，设置标志位
	weapon_admin.current_weapon.anim.animation_finished.connect(_on_animation_finished)
	# 执行攻击
	weapon_admin.current_weapon.play_attack()


func _on_next_transitions() -> void:
	# 检查标志位，如果为 true，则切换状态
	if _is_animation_finished:
		transition.emit("weapon_idle")


func _on_exit() -> void:
	# 退出状态时，断开信号，是一个好习惯
	if weapon_admin.current_weapon.anim.animation_finished.is_connected(_on_animation_finished):
		weapon_admin.current_weapon.anim.animation_finished.disconnect(_on_animation_finished)


# 信号回调函数
func _on_animation_finished(_anim_name: StringName) -> void:
	_is_animation_finished = true
