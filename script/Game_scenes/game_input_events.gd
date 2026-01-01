extends Node
class_name GameInputEvents

static var direction:Vector2
static var isDashing : bool = false
static var canDash : bool = true


static func movement_input() -> Vector2:

	direction = Input.get_vector("left","right","up","down")
	return direction

static func is_movement_input() -> bool:

	if direction == Vector2.ZERO:
		return false
	else:
		return true

static func is_dash_input() -> bool:

	#按下空格，并且冲刺CD满足的情况下
	if Input.is_action_just_pressed("dash") && canDash == true:
		isDashing = true
	return isDashing

static func attack_input() -> bool:
	return Input.is_action_just_pressed("attack")

static func special_attack_input() -> bool:
	# 假设你的右键没有绑定 InputMap，直接检测鼠标右键
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	
	# 如果你在项目设置里绑定了 "attack_2" 或 "special_attack"，也可以改成：
	# return Input.is_action_pressed("attack_2") # 注意是 pressed 不是 just_pressed


static func switch_weapons() -> int:

	var weaponID : int = -1

	if Input.is_action_just_pressed("weapon_1"):
		weaponID = 0
	elif Input.is_action_just_pressed("weapon_2"):
		weaponID = 1
	return weaponID
