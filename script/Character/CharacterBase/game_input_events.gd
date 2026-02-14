extends Node
class_name GameInputEvents

## 全局输入管理器
## 职责：统一处理玩家输入检测，提供静态方法供其他脚本调用。
## 特性：不存储游戏逻辑状态（如是否在冲刺、能否冲刺），只负责返回按键事实。

# [全局开关] 控制是否允许输入 (例如剧情对话时设为 false)
static var input_enabled: bool = true

# 缓存输入向量
static var direction: Vector2

#region 移动输入 (Movement)

## 获取移动方向向量 (归一化)
static func movement_input() -> Vector2:
	if not input_enabled: return Vector2.ZERO
	
	# 使用 get_vector 可以获得更平滑的手感 (支持手柄摇杆)
	direction = Input.get_vector("left", "right", "up", "down")
	return direction

## 判断是否有移动输入
static func is_movement_input() -> bool:
	if not input_enabled: return false
	return movement_input() != Vector2.ZERO

## 检测冲刺按键 (只检测按下动作，不判断 CD)
## 冷却和耐力判断交由 CharacterStatsComponent.check_and_consume_dash() 处理
static func is_dash_input() -> bool:
	if not input_enabled: return false
	return Input.is_action_just_pressed("dash")

#endregion

#region 攻击输入 (Attack)

## 检测主攻击键 (左键) 是否刚刚按下
static func is_main_attack_just_pressed() -> bool:
	if not input_enabled: return false
	return Input.is_action_just_pressed("mouse_left")

## 检测主攻击键 (左键) 是否按住
static func is_main_attack_held() -> bool:
	if not input_enabled: return false
	return Input.is_action_pressed("mouse_left")

## 检测特殊攻击键 (右键) 是否按住
static func is_special_attack_held() -> bool:
	if not input_enabled: return false
	return Input.is_action_pressed("mouse_right")

## 检测特殊攻击键 (右键) 是否刚刚按下
static func is_special_attack_just_pressed() -> bool:
	if not input_enabled: return false
	return Input.is_action_just_pressed("mouse_right")

#endregion

#region 武器切换 (Weapon Switch)

## 检测武器切换按键，返回武器 ID，无切换则返回 -1
static func switch_weapons() -> int:
	if not input_enabled: return -1

	if Input.is_action_just_pressed("weapon_1"):
		return 0
	elif Input.is_action_just_pressed("weapon_2"):
		return 1
		
	return -1

#endregion
