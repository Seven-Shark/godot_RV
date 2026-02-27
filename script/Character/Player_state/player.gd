extends CharacterBase
class_name Player

## Player.gd
## 职责：处理玩家特有的输入交互、瞄准模式、视觉反馈以及响应自动攻击信号。
## 特性：支持自动锁定、鼠标辅助瞄准、攻击范围可视化、目标选中框以及【按键 E 硬锁定目标】。

#region 1. 节点引用
@onready var state_machine: NodeStateMachine = $StateMachine ## 引用玩家状态机节点
#endregion

#region 2. 瞄准与视觉配置
@export_group("Aim & Visual Settings")
@export var show_auto_attack_range: bool = true ## 是否在画面上绘制自动攻击的范围圈
@export var auto_attack_radius: float = 250.0 ## 自动攻击的视觉范围半径 (建议与 DetectionArea 的半径保持一致)
@export var range_color_normal: Color = Color(1.0, 1.0, 1.0, 0.3) ## 无目标时的范围圈颜色 (半透明白)
@export var range_color_active: Color = Color(1.0, 1.0, 0.0, 0.6) ## 有触发目标时的范围圈颜色 (半透明黄)

@export var target_indicator: Sprite2D ## 目标选中框贴图节点

const ASSIST_ANGLE = 90.0   ## 鼠标辅助瞄准的扇形夹角 (度)
const ASSIST_RANGE = 250.0  ## 鼠标辅助瞄准的有效距离
const ASSIST_RANGE_SQ = ASSIST_RANGE * ASSIST_RANGE ## 预计算的距离平方 (用于性能优化)
#endregion

#region 3. 枚举与内部变量
enum AimMode_Type {
	AUTO_NEAREST, ## 自动锁定范围内最近的有效目标
	MOUSE_ASSIST  ## 鼠标辅助扇形瞄准模式
}

var player_current_aim_mode: AimMode_Type = AimMode_Type.AUTO_NEAREST ## 当前玩家处于的瞄准模式
var hard_locked_target: Node2D = null ## 当前被玩家强行锁定的目标
#endregion

#region 4. 生命周期与输入
func _ready() -> void:
	character_type = CharacterType.PLAYER
	super._ready() 
	
	if not on_perform_attack.is_connected(_on_perform_auto_attack):
		on_perform_attack.connect(_on_perform_auto_attack)

func _input(event: InputEvent) -> void:
	# 监听目标锁定指令 (E 键)
	if GameInputEvents.is_lock_target_event(event):
		if is_instance_valid(hard_locked_target):
			hard_locked_target = null
			print(">>> [Player] 解除目标锁定")
		else:
			if is_instance_valid(current_target):
				hard_locked_target = current_target
				print(">>> [Player] 锁定目标: ", hard_locked_target.name)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	var current_state = ""
	if state_machine:
		current_state = state_machine.current_node_state_name.to_lower()

	# 冲刺或攻击状态下不累加自动攻击的进度
	if current_state == "dash":
		reset_attack_progress(true)
		return

	if current_state == "attack":
		return 

	# 根据当前瞄准模式，决定是否推进自动攻击进度条
	match player_current_aim_mode:
		AimMode_Type.AUTO_NEAREST:
			if is_instance_valid(hard_locked_target):
				# 【硬锁定状态】：只有靠近锁定目标才触发攻击
				if enter_Character.has(hard_locked_target):
					update_auto_attack_progress(delta)
				else:
					reset_attack_progress(true)
			else:
				# 【常规状态】：走原有的自动攻击逻辑
				update_auto_attack_progress(delta)
			
		AimMode_Type.MOUSE_ASSIST:
			reset_attack_progress(true)

func _process(delta: float) -> void:
	# =========================================================
	# [终极生死拦截] 只要血量归零或判定死亡，立刻强行关闭一切 UI 和瞄准逻辑
	if is_dead or (stats and stats.current_health <= 0):
		if is_instance_valid(target_indicator): target_indicator.visible = false
		if is_instance_valid(direction_Sign): direction_Sign.visible = false
		hard_locked_target = null
		queue_redraw() # 强制擦除地上的攻击范围圈
		return
	# =========================================================

	_update_facing_direction()
	
	var mouse_pos = get_global_mouse_position()
	var final_target: Node2D = _get_target_by_mode(mouse_pos)
	
	_update_target_locking(final_target)
	_update_DirectionSign_Visible(mouse_pos)
	_update_target_indicator_visual(delta)
	
	queue_redraw()

func _draw() -> void:
	# 死亡状态下禁止绘图
	if is_dead or (stats and stats.current_health <= 0): return
	
	match player_current_aim_mode:
		AimMode_Type.MOUSE_ASSIST:
			var mouse_pos = get_global_mouse_position()
			var to_mouse = (mouse_pos - global_position).normalized()
			var angle = deg_to_rad(ASSIST_ANGLE / 2.0)
			
			draw_line(Vector2.ZERO, to_mouse.rotated(angle) * ASSIST_RANGE, Color(1, 0, 0, 0.5), 2.0)
			draw_line(Vector2.ZERO, to_mouse.rotated(-angle) * ASSIST_RANGE, Color(1, 0, 0, 0.5), 2.0)
			
		AimMode_Type.AUTO_NEAREST:
			if show_auto_attack_range:
				var current_color = range_color_normal
				
				if is_instance_valid(hard_locked_target):
					# 【硬锁定状态】：只有锁定的目标进入范围，圈才会变黄
					if enter_Character.has(hard_locked_target):
						current_color = range_color_active
				else:
					# 【常规状态】：范围内有任何有效目标就变黄
					if not enter_Character.is_empty():
						for body in enter_Character:
							if is_instance_valid(body):
								var is_valid := false
								if body is CharacterBase:
									is_valid = not body.is_dead 
								elif body is WorldEntity:
									is_valid = true 
								
								if is_valid:
									current_color = range_color_active
									break 

				draw_arc(Vector2.ZERO, auto_attack_radius, 0.0, TAU, 64, current_color, 2.0)

## --- [新增] 重写父类的死亡逻辑，处理玩家特有的 UI 清理 ---
func _die() -> void:
	# 1. 抢在父类掐断脚本之前，先把玩家的专属瞄准 UI 关掉
	if is_instance_valid(target_indicator): 
		target_indicator.visible = false
	if is_instance_valid(direction_Sign): 
		direction_Sign.visible = false
	queue_redraw() # 强制擦除地上的攻击范围圈
	
	# 2. 调用父类的通用死亡逻辑（执行真正的扣血、动画和 set_process(false)）
	super._die()
## --------------------------------------------------------
## [复活覆盖] 重写父类状态重置，清理玩家独有的变量
func reset_status() -> void:
	hard_locked_target = null # 复活时确保锁定目标为空
	player_current_aim_mode = AimMode_Type.AUTO_NEAREST # 可选：复活时默认切回自动瞄准
	super.reset_status() # 调用父类的复活加血等逻辑

#endregion

#region 5. 战斗响应 (核心)
func _on_perform_auto_attack(target: Node2D) -> void:
	print(">>> [Player] 自动攻击触发！目标: ", target.name)
	if state_machine:
		state_machine.transition_to("Attack")
#endregion

#region 6. 目标获取逻辑
func _get_target_by_mode(mouse_pos: Vector2) -> Node2D:
	# 强制拦截：如果存在硬锁定目标，且存活，无视距离强行返回它
	if is_instance_valid(hard_locked_target):
		var is_valid := false
		if hard_locked_target is CharacterBase:
			is_valid = not hard_locked_target.is_dead
		elif hard_locked_target is WorldEntity:
			is_valid = true
			
		if is_valid:
			return hard_locked_target
		else:
			hard_locked_target = null
	
	match player_current_aim_mode:
		AimMode_Type.AUTO_NEAREST:
			return get_closest_target()
		AimMode_Type.MOUSE_ASSIST:
			return get_mouse_assist_target(mouse_pos)
	return null

func get_mouse_assist_target(mouse_position: Vector2) -> Node2D:
	var self_pos = global_position
	var to_mouse_dir = (mouse_position - self_pos).normalized()
	var closest_assist_target: Node2D = null 
	var closest_dist_sq = INF
	var half_angle_rad = deg_to_rad(ASSIST_ANGLE / 2.0)
	
	for body in enter_Character:
		if not is_instance_valid(body): continue
		
		var is_valid_target = false
		
		if body is CharacterBase and target_types.has(body.character_type):
			if not body.is_dead: is_valid_target = true
			
		elif body is WorldEntity and target_entity_types.has(body.entity_type):
			is_valid_target = true
			
		if not is_valid_target: continue
			
		var target_vec = body.global_position - self_pos
		var dist_sq = target_vec.length_squared()
		
		if dist_sq <= ASSIST_RANGE_SQ:
			if abs(to_mouse_dir.angle_to(target_vec)) <= half_angle_rad:
				if dist_sq < closest_dist_sq:
					closest_dist_sq = dist_sq
					closest_assist_target = body
						
	return closest_assist_target

func _update_target_locking(new_target: Node2D) -> void:
	if new_target and new_target != current_target:
		current_target = new_target
	elif not new_target and is_instance_valid(current_target):
		current_target = null
#endregion

#region 7. 视觉表现
## 控制目标选中框的显示与位置跟随
func _update_target_indicator_visual(delta: float) -> void:
	if not is_instance_valid(target_indicator): return
	
	if is_instance_valid(current_target):
		var is_valid := false
		if current_target is CharacterBase:
			is_valid = not current_target.is_dead
		elif current_target is WorldEntity:
			is_valid = true
			
		if is_valid:
			target_indicator.visible = true
			target_indicator.global_position = current_target.global_position
			
			# 视觉反馈：硬锁定时变红，软选中时为白色
			if current_target == hard_locked_target:
				target_indicator.modulate = Color(1.0, 0.2, 0.2)
			else:
				target_indicator.modulate = Color.WHITE
			return
			
	target_indicator.visible = false

func _update_facing_direction() -> void:
	var look_at_point = null
	
	match player_current_aim_mode:
		AimMode_Type.MOUSE_ASSIST:
			look_at_point = get_global_mouse_position()
		AimMode_Type.AUTO_NEAREST:
			if is_instance_valid(current_target):
				look_at_point = current_target.global_position
	
	if look_at_point != null:
		var direction_factor = -1 if flipped_horizontal else 1
		if look_at_point.x > global_position.x:
			sprite.scale.x = direction_factor
		elif look_at_point.x < global_position.x:
			sprite.scale.x = -direction_factor
	else:
		Turn()

func _update_DirectionSign_Visible(mouse_pos: Vector2) -> void:
	if not is_instance_valid(direction_Sign): return
	
	match player_current_aim_mode:
		AimMode_Type.AUTO_NEAREST:
			if is_instance_valid(current_target):
				direction_Sign.visible = true
				Target_Lock_On(current_target)
			else:
				direction_Sign.visible = false
				Target_Lock_On(null)
				
		AimMode_Type.MOUSE_ASSIST:
			direction_Sign.visible = true
			if is_instance_valid(current_target):
				Target_Lock_On(current_target)
			else:
				_look_at_mouse(mouse_pos)

func _look_at_mouse(mouse_position: Vector2) -> void:
	if is_instance_valid(direction_Sign):
		var direction_vector = mouse_position - global_position
		direction_Sign.rotation = direction_vector.angle()
		direction_Sign.visible = true
#endregion

#region 8. 接口
func toggle_aim_mode() -> void:
	if player_current_aim_mode == AimMode_Type.AUTO_NEAREST:
		player_current_aim_mode = AimMode_Type.MOUSE_ASSIST
		if direction_Sign: direction_Sign.visible = true
		print("当前模式：鼠标瞄准")
	else:
		player_current_aim_mode = AimMode_Type.AUTO_NEAREST
		if direction_Sign: direction_Sign.visible = false
		print("当前模式：自动瞄准")
#endregion
