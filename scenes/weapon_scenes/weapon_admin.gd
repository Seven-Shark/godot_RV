class_name WeaponAdmin
extends Node2D


# 当当前武器动作结束时（比如攻击动画播完），发送这个信号
signal action_finished

var weapons:Array[Node2D] = []
var current_weapon:Node2D
var character_owner:CharacterBase


@onready var weaponlist = $WeaponCurrent



func _process(_delta):

	#切换武器
	switch_weapons()
	#武器朝向与角色一致
	_sync_weapon_facing_direction()
	#攻击判定框与攻击方向保持一致
	_sync_hitbox_rotation()

func _ready() -> void:

	#确认武器的所有者是谁
	_check_owner()
	
	# 获取所有子节点作为武器
	# 注意：默认武器是列表中的第一个。请确保在场景树中，Axe是 WeaponCurrent 下的第一个节点。
	for child in weaponlist.get_children():
		if child is Node2D:
			weapons.append(child)
			child.visible = false

	#默认装备第一把武器
	if weapons.size() > 0:
		equip_weapon(weapons[0])

func _check_owner() -> CharacterBase:
	if owner is CharacterBase:
		character_owner = owner
	elif get_parent() is CharacterBase:
		character_owner = get_parent()
	if not character_owner:
		push_error("WeaponAdmin 未找到 CharacterBase 类型的持有者！")
	return character_owner

#监听数字键切换武器
func switch_weapons():

	var weapon_id_input = GameInputEvents.switch_weapons()

	if weapon_id_input == -1:
		return
	if weapon_id_input == 0 and weapons.size()>0:
		equip_weapon(weapons[0])
		print("当前武器：Axe")
	elif weapon_id_input == 1 and weapons.size()>1:
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
	
	#检查武器是否有belonger变量，有得话就把持有者信息同步给它
	if "belonger" in current_weapon:
		current_weapon.belonger = character_owner
	
	# 装备武器后，播放其待机动画
	if current_weapon.has_method("play_idle"):
		current_weapon.play_idle()

# 让武器朝向和角色朝向保持一致
func _sync_weapon_facing_direction():

	if is_instance_valid(owner) and owner is CharacterBase and is_instance_valid(current_weapon):
		if is_instance_valid(owner.sprite):
			current_weapon.scale.x = owner.sprite.scale.x

# 让武器攻击判断框与攻击方向同步旋转,并在攻击时禁止旋转，攻击束后再旋转
func _sync_hitbox_rotation():
	
	#确保有武器
	if not is_instance_valid(current_weapon):
		return
	var hitbox = current_weapon.get_node_or_null("Weapon_Hitbox")
	if not hitbox:
		return
	
	var player = owner
	var direction_sign = player.get_node_or_null("DirectionSign")
	
	if direction_sign:
		hitbox.global_rotation = direction_sign.global_rotation 
	
	var state_machine = player.get_node_or_null("WeaponStateMachine")
	
	

#接收子武器的信号，并转发给 WeaponAdmin
func _on_child_weapon_finished():
	action_finished.emit()
