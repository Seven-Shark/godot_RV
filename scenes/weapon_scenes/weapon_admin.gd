class_name WeaponAdmin
extends Node2D


# 当当前武器动作结束时（比如攻击动画播完），发送这个信号
signal action_finished

var weapons:Array[Node2D] = []
var current_weapon:Node2D

@onready var weaponlist = $WeaponCurrent

func _ready() -> void:
	
	#获取所有子节点作为武器
	for child in weaponlist.get_children():
		if child is Node2D:
			weapons.append(child)
			child.visible = false
				
			if child.has_signal("weapon_finished"):
				child.weapon_finished.connect(_on_child_weapon_finished)
	#默认装备第一把武器
	if weapons.size() > 0:
		equip_weapon(weapons[0])
	
#监听数字键切换武器
func _unhandled_input(event: InputEvent) -> void:	 

	if event.is_action_pressed("weapon_1") and weapons.size()>0:
		equip_weapon(weapons[0])
		print("当前武器：Axe")
	elif event.is_action_pressed("weapon_2") and weapons.size()>1:
		equip_weapon(weapons[1])
		print("当前武器：Sword")

#切换武器逻辑
func equip_weapon(weapon_node:Node2D) -> void:
	if current_weapon == weapon_node:
		return

	if current_weapon:
		current_weapon.visible = false

	current_weapon = weapon_node
	current_weapon.visible = true

	#切换武器时，立即尝试让新武器进入ilde状态
	enter_idle_state()

#有idle状态调用idle状态
func enter_idle_state():
	if current_weapon and current_weapon.has_method("play_idle"):
		current_weapon.play_idle()

#有attack状态调用attack状态
func enter_attack_state():
	if current_weapon and current_weapon.has_method("play_attack"):
		current_weapon.play_attack()

#接收子武器的信号，并转发给 WeaponAdmin
func _on_child_weapon_finished():
	action_finished.emit()
