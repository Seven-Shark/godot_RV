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

# --- 攻击输入扩充 ---

# 1. 主攻击（震荡波）：需要支持连发，检测 "Pressed" (按住)
static func is_main_attack_held() -> bool:
	return Input.is_action_pressed("mouse_left")

# 【新增】主攻击（发射重物）：只需要单次点击，检测 "Just Pressed"
static func is_main_attack_just_pressed() -> bool:
	return Input.is_action_just_pressed("mouse_left")

# 2. 特殊攻击（引力波）：需要持续施法，检测 "Pressed" (按住)
static func is_special_attack_held() -> bool:
	return Input.is_action_pressed("mouse_right")

# 【新增】特殊攻击（放下重物）：只需要单次点击，检测 "Just Pressed"
static func is_special_attack_just_pressed() -> bool:
	return Input.is_action_just_pressed("mouse_right")

#static func special_attack_input() -> bool:
	## 假设你的右键没有绑定 InputMap，直接检测鼠标右键
	#return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	
	# 如果你在项目设置里绑定了 "attack_2" 或 "special_attack"，也可以改成：
	# return Input.is_action_pressed("attack_2") # 注意是 pressed 不是 just_pressed


static func switch_weapons() -> int:

	var weaponID : int = -1

	if Input.is_action_just_pressed("weapon_1"):
		weaponID = 0
	elif Input.is_action_just_pressed("weapon_2"):
		weaponID = 1
	return weaponID
