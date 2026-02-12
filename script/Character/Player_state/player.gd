extends CharacterBase
class_name Player

## Player.gd
## 职责：处理玩家特有的输入交互、瞄准模式、视觉反馈以及响应自动攻击信号。

#region 1. 节点引用
@onready var state_machine: NodeStateMachine = $StateMachine ## 引用状态机，用于切换攻击状态
#endregion

#region 2. 瞄准配置
const ASSIST_ANGLE = 90.0   ## 辅助瞄准角度
const ASSIST_RANGE = 250.0  ## 辅助瞄准距离
const ASSIST_RANGE_SQ = ASSIST_RANGE * ASSIST_RANGE
#endregion

#region 3. 枚举与变量
enum AimMode_Type {
	AUTO_NEAREST, ## 自动锁定最近
	MOUSE_ASSIST  ## 鼠标辅助扇形
}
var player_current_aim_mode: AimMode_Type = AimMode_Type.AUTO_NEAREST
#endregion

#region 4. 生命周期
func _init() -> void:
	# 设置阵营与目标类型
	character_type = CharacterType.PLAYER
	target_types = [CharacterType.ITEM, CharacterType.ENEMY]

func _ready() -> void:
	super._ready() # [必须] 调用父类初始化，否则层级记忆和侦查圈失效
	
	# [新增] 连接父类的自动攻击信号
	if not on_perform_attack.is_connected(_on_perform_auto_attack):
		on_perform_attack.connect(_on_perform_auto_attack)

func _physics_process(delta: float) -> void:
	# 1. 调用父类物理逻辑
	super._physics_process(delta)

	# [修改] 攻击状态下，进行“部分重置” (False)
	if state_machine.current_node_state_name == "attack":
		reset_attack_progress(false) 
		return

	# 2. 根据瞄准模式控制自动攻击
	match player_current_aim_mode:
		AimMode_Type.AUTO_NEAREST:
			# 自动模式：计算进度
			update_auto_attack_progress(delta)
			
		AimMode_Type.MOUSE_ASSIST:
			# 鼠标模式：强制“完全重置” (True)
			reset_attack_progress(true)
			
func _process(_delta: float) -> void:
	# 1. 视觉朝向
	_update_facing_direction()

	# 2. 获取鼠标位置
	var mouse_pos = get_global_mouse_position()
	
	# 3. 获取目标 [修改] 类型改为 Node2D
	var final_target: Node2D = _get_target_by_mode(mouse_pos)
	
	# 4. 更新锁定
	_update_target_locking(final_target)
	
	# 5. 更新指示箭头
	_update_DirectionSign_Visible(mouse_pos)
	
	# 6. Debug 绘制
	queue_redraw()

func _draw() -> void:
	if player_current_aim_mode == AimMode_Type.MOUSE_ASSIST:
		var mouse_pos = get_global_mouse_position()
		var to_mouse = (mouse_pos - global_position).normalized()
		var angle = deg_to_rad(ASSIST_ANGLE / 2.0)
		
		draw_line(Vector2.ZERO, to_mouse.rotated(angle) * ASSIST_RANGE, Color(1, 0, 0, 0.5), 2)
		draw_line(Vector2.ZERO, to_mouse.rotated(-angle) * ASSIST_RANGE, Color(1, 0, 0, 0.5), 2)
#endregion

#region 5. 战斗响应 (核心)
## [回调] 当自动攻击蓄力完成时触发
## [修改] 参数类型改为 Node2D，以接收 WorldEntity
func _on_perform_auto_attack(target: Node2D) -> void:
	print(">>> [Player] 自动攻击触发！目标: ", target.name)
	
	# 1. 可以在这里生成子弹逻辑 (例如调用 WeaponManager)
	# create_bullet(target)
	
	# 2. [关键] 切换状态机到 Attack 状态
	if state_machine:
		state_machine.transition_to("Attack")
#endregion

#region 6. 目标获取逻辑
## [修改] 返回类型改为 Node2D
func _get_target_by_mode(mouse_pos: Vector2) -> Node2D:
	match player_current_aim_mode:
		AimMode_Type.AUTO_NEAREST:
			return get_closest_target()
		AimMode_Type.MOUSE_ASSIST:
			return get_mouse_assist_target(mouse_pos)
	return null

## [修改] 返回类型改为 Node2D
func get_mouse_assist_target(mouse_position: Vector2) -> Node2D:
	var self_pos = global_position
	var to_mouse_dir = (mouse_position - self_pos).normalized()
	var closest_assist_target: Node2D = null # 类型改为 Node2D
	var closest_dist_sq = INF
	
	var half_angle_rad = deg_to_rad(ASSIST_ANGLE / 2.0)
	
	# 使用父类的 enter_Character (现在里面存的是 Node2D)
	for body in enter_Character:
		if not is_instance_valid(body): continue
		
		# 逻辑判断：是敌人且未死，或者是物件
		var is_valid_target = false
		if body is CharacterBase and target_types.has(body.character_type):
			if not body.is_dead: is_valid_target = true
		elif body is WorldEntity and body.entity_type == WorldEntity.EntityType.PROP:
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

## [修改] 参数类型改为 Node2D
func _update_target_locking(new_target: Node2D) -> void:
	if new_target and new_target != current_target:
		current_target = new_target
	elif not new_target and is_instance_valid(current_target):
		current_target = null
#endregion

#region 7. 视觉表现
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
		direction_Sign.visible = true
		print("当前模式：鼠标瞄准")
	else:
		player_current_aim_mode = AimMode_Type.AUTO_NEAREST
		direction_Sign.visible = false
		print("当前模式：自动瞄准")
#endregion
