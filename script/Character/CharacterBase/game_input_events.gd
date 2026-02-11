extends Node
class_name GameInputEvents

# [新增] 全局输入开关：默认为 true (允许输入)
static var input_enabled: bool = true

static var direction: Vector2
static var isDashing : bool = false
static var canDash : bool = true

static func movement_input() -> Vector2:
	# [新增] 如果开关关闭，直接返回 0 向量，角色就会停下
	if not input_enabled:
		return Vector2.ZERO

	direction = Input.get_vector("left","right","up","down")
	return direction

static func is_movement_input() -> bool:
	# [新增]
	if not input_enabled: return false

	if direction == Vector2.ZERO:
		return false
	else:
		return true

static func is_dash_input() -> bool:
	# [新增]
	if not input_enabled: return false

	#按下空格，并且冲刺CD满足的情况下
	if Input.is_action_just_pressed("dash") && canDash == true:
		isDashing = true
	return isDashing

# --- 攻击输入扩充 ---

static func is_main_attack_held() -> bool:
	if not input_enabled: return false # [新增]
	return Input.is_action_pressed("mouse_left")

static func is_main_attack_just_pressed() -> bool:
	if not input_enabled: return false # [新增]
	return Input.is_action_just_pressed("mouse_left")

static func is_special_attack_held() -> bool:
	if not input_enabled: return false # [新增]
	return Input.is_action_pressed("mouse_right")

static func is_special_attack_just_pressed() -> bool:
	if not input_enabled: return false # [新增]
	return Input.is_action_just_pressed("mouse_right")

static func switch_weapons() -> int:
	if not input_enabled: return -1 # [新增]

	var weaponID : int = -1

	if Input.is_action_just_pressed("weapon_1"):
		weaponID = 0
	elif Input.is_action_just_pressed("weapon_2"):
		weaponID = 1
	return weaponID
