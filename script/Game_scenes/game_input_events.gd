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
	
	
	
