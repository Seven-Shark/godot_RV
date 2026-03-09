extends Node
class_name GameInputEvents

## GameInputEvents.gd
## 全局输入管理器
## 职责：统一处理玩家输入检测，提供静态方法供其他脚本调用。
## 特性：不存储游戏逻辑状态，只负责返回按键事实。支持 Input Map 映射与硬编码键位双重兼容。

# [全局开关] 控制是否允许输入 (例如剧情对话时设为 false)
static var input_enabled: bool = true

# 缓存输入向量
static var direction: Vector2

#region 1. 移动输入 (Movement)
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
static func is_dash_input() -> bool:
	if not input_enabled: return false
	return Input.is_action_just_pressed("dash")
#endregion

#region 2. 攻击输入 (Attack)
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

#region 3. 武器切换 (Weapon Switch)
## 检测武器切换按键，返回武器 ID，无切换则返回 -1
static func switch_weapons() -> int:
	if not input_enabled: return -1

	if Input.is_action_just_pressed("weapon_1"):
		return 0
	elif Input.is_action_just_pressed("weapon_2"):
		return 1
		
	return -1
#endregion

#region 4. 交互与功能按键 (Interaction & Toggles)
## 检测是否触发了【目标锁定】 (默认 shift 键)
static func is_lock_target_event(event: InputEvent) -> bool:
	if not input_enabled: return false
	if event.is_action_pressed("lock_target"): return true
	return false

## 检测是否触发了【打开背包】 (默认 Tab 键)
static func is_open_bag(event: InputEvent) -> bool:
	if not input_enabled: return false
	if event.is_action_pressed("openbag"): return true
	return false

## 检测是否触发了【交互】 (默认 E 键)
static func is_interact_event(event: InputEvent) -> bool:
	if not input_enabled: return false
	if event.is_action_pressed("interact"): return true
	return false

## 检测交互键(E)松开 (用于 UI 中的长按建造取消)
static func is_interact_released(event: InputEvent) -> bool:
	if not input_enabled: return false
	return event.is_action_released("interact")

## 检测是否触发了【自动吸附开关】 (默认 Q 键)
static func is_toggle_magnet_event(event: InputEvent) -> bool:
	if not input_enabled: return false
	if event.is_action_pressed("toggle_magnet"): return true
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q and not event.echo:
		return true
	return false

## 检测是否触发了【取消/退出】 (默认 ESC 键)
static func is_cancel_event(event: InputEvent) -> bool:
	if not input_enabled: return false
	if event.is_action_pressed("ui_cancel"): return true
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: return true
	return false
#endregion

#region 5. UI 导航 (UI Navigation)
## 检测 UI 向上 (默认 W 或 上方向键)
static func is_ui_up(event: InputEvent) -> bool:
	if not input_enabled: return false
	return event.is_action_pressed("ui_up") or (event is InputEventKey and event.keycode == KEY_W and event.pressed)

## 检测 UI 向下 (默认 S 或 下方向键)
static func is_ui_down(event: InputEvent) -> bool:
	if not input_enabled: return false
	return event.is_action_pressed("ui_down") or (event is InputEventKey and event.keycode == KEY_S and event.pressed)

## 检测 UI 向左 (默认 A 或 左方向键) - 用于 Tab 切换
static func is_ui_left(event: InputEvent) -> bool:
	if not input_enabled: return false
	return event.is_action_pressed("ui_left") or (event is InputEventKey and event.keycode == KEY_A and event.pressed)

## 检测 UI 向右 (默认 D 或 右方向键) - 用于 Tab 切换
static func is_ui_right(event: InputEvent) -> bool:
	if not input_enabled: return false
	return event.is_action_pressed("ui_right") or (event is InputEventKey and event.keycode == KEY_D and event.pressed)
#endregion
