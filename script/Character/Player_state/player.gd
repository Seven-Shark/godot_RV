extends CharacterBase
class_name Player

## 玩家控制类
##
## 负责处理玩家特有的逻辑，包括：
## 1. 瞄准模式切换 (自动/鼠标辅助)
## 2. 目标锁定与索敌计算
## 3. 视觉朝向与辅助线绘制

#region 瞄准配置
const ASSIST_ANGLE = 90.0        # 辅助瞄准角度 (扇形开口)
const ASSIST_RANGE = 250.0       # 辅助瞄准最大距离
const ASSIST_RANGE_SQ = ASSIST_RANGE * ASSIST_RANGE # 距离平方 (用于性能优化比较)
#endregion

#region 枚举定义
enum AimMode_Type {
	AUTO_NEAREST, # 自动瞄准：总是锁定最近的敌人
	MOUSE_ASSIST  # 鼠标辅助：锁定鼠标指向区域内的敌人
}
#endregion

# 默认瞄准模式
var player_current_aim_mode = AimMode_Type.MOUSE_ASSIST

func _init() -> void:
	character_type = CharacterType.PLAYER
	# 设置该角色追踪的目标类型 (继承自 CharacterBase)
	target_types = [CharacterType.ITEM, CharacterType.ENEMY]

func _process(_delta):
	# 1. 视觉：根据移动方向或目标改变图片朝向
	_update_facing_direction()

	# 2. 逻辑：获取当前鼠标位置
	var mouse_pos = get_global_mouse_position()
	
	# 3. 逻辑：根据模式获取目标
	var final_target: CharacterBase = _get_target_by_mode(mouse_pos)
	
	# 4. 状态：更新锁定状态
	_update_target_locking(final_target)
	
	# 5. 视觉：更新指示器 (箭头) 的显隐和指向
	_update_DirectionSign_Visible(mouse_pos)
	
	# 6. 调试：请求重绘 (用于画出辅助线)
	queue_redraw()

# 在鼠标辅助准模式下，画两条指示范围的线 (Debug用)
func _draw():
	if player_current_aim_mode == AimMode_Type.MOUSE_ASSIST:
		var mouse_pos = get_global_mouse_position()
		var to_mouse = (mouse_pos - global_position).normalized()
		var angle = deg_to_rad(ASSIST_ANGLE / 2.0)
		
		# 绘制扇形边界线
		draw_line(Vector2.ZERO, to_mouse.rotated(angle) * ASSIST_RANGE, Color(1, 0, 0, 0.5), 2)
		draw_line(Vector2.ZERO, to_mouse.rotated(-angle) * ASSIST_RANGE, Color(1, 0, 0, 0.5), 2)

#region 目标获取与计算
# 根据不同的瞄准模式来分发获取目标的逻辑
func _get_target_by_mode(mouse_pos: Vector2) -> CharacterBase:
	match player_current_aim_mode:
		AimMode_Type.AUTO_NEAREST:
			# 自动模式：直接调用父类的获取最近目标方法
			return get_closest_target()
		AimMode_Type.MOUSE_ASSIST:
			# 鼠标模式：获取鼠标扇形区域内的最近目标
			return get_mouse_assist_target(mouse_pos)
	return null

# [核心算法] 鼠标瞄准辅助攻击逻辑
func get_mouse_assist_target(mouse_position: Vector2) -> CharacterBase:
	# 确认瞄准中心方向：玩家到鼠标方向向量
	var self_pos = global_position
	var to_mouse_dir = (mouse_position - self_pos).normalized()
	var closest_assist_target: CharacterBase = null
	var closest_dist_sq = INF
	
	# 扇形一半角度（弧度制）
	var half_angle_rad = deg_to_rad(ASSIST_ANGLE / 2.0)
	var target_array: Array = detection_Area.get_overlapping_bodies()
	
	# 遍历所有潜在目标
	for body in target_array:
		# 必须是 CharacterBase, 不是自己, 且是该角色要追踪的类型
		if body is CharacterBase and body != self and target_types.has(body.character_type):
			var target_vec = body.global_position - self_pos
			var dist_sq = target_vec.length_squared()
			
			# 条件 A: 距离在辅助范围内
			if dist_sq <= ASSIST_RANGE_SQ:
				# 条件 B: 角度在鼠标指向的扇形范围内
				if abs(to_mouse_dir.angle_to(target_vec)) <= half_angle_rad:
					# 条件 C: 找出距离最近的那个
					if dist_sq < closest_dist_sq:
						closest_dist_sq = dist_sq
						closest_assist_target = body
						
	return closest_assist_target

# 锁定目标状态更新，处理目标切换和丢失
func _update_target_locking(new_target: CharacterBase):
	# 场景 1: 找到了新目标，且和当前不一样 -> 切换锁定
	if new_target and new_target != current_target:
		print("锁定目标：", new_target.name)
		current_target = new_target
	# 场景 2: 没找到新目标，但当前还锁着一个 -> 丢失目标
	elif not new_target and is_instance_valid(current_target):
		print("【目标丢失】解除锁定")
		current_target = null
#endregion

#region 朝向与指示器
# 处理角色 Sprite 朝向的逻辑
func _update_facing_direction():
	var look_at_point = null
	
	# 1. 确定关注点
	match player_current_aim_mode:
		AimMode_Type.MOUSE_ASSIST:
			look_at_point = get_global_mouse_position()
		AimMode_Type.AUTO_NEAREST:
			if is_instance_valid(current_target):
				look_at_point = current_target.global_position
			else:
				look_at_point = null
	
	# 2. 执行翻转
	if look_at_point != null:
		var direction_factor = -1 if flipped_horizontal else 1
		
		if look_at_point.x > global_position.x:
			sprite.scale.x = direction_factor
		elif look_at_point.x < global_position.x:
			sprite.scale.x = -direction_factor
	else:
		# 如果没有关注点，回退到基于移动速度的翻转 (父类方法)
		Turn()

# 控制指示器 (DirectionSign) 的显隐和指向
func _update_DirectionSign_Visible(mouse_pos: Vector2):
	if not is_instance_valid(direction_Sign):
		return
		
	match player_current_aim_mode:
		AimMode_Type.AUTO_NEAREST:
			# 【自动模式】：有目标才显示，没目标隐藏
			if is_instance_valid(current_target):
				direction_Sign.visible = true
				Target_Lock_On(current_target)
			else:
				direction_Sign.visible = false
				Target_Lock_On(null)
				
		AimMode_Type.MOUSE_ASSIST:
			# 【鼠标模式】：箭头常驻
			direction_Sign.visible = true
			if is_instance_valid(current_target):
				Target_Lock_On(current_target)
			else:
				_look_at_mouse(mouse_pos)

# 箭头指向鼠标 (未锁定目标时的默认行为)
func _look_at_mouse(mouse_position: Vector2):
	if is_instance_valid(direction_Sign):
		var direction_vector = mouse_position - global_position
		direction_Sign.rotation = direction_vector.angle()
		direction_Sign.visible = true
#endregion

#region 输入控制与杂项
# 切换瞄准模式 (通常由外部输入调用)
func toggle_aim_mode():
	if player_current_aim_mode == AimMode_Type.AUTO_NEAREST:
		player_current_aim_mode = AimMode_Type.MOUSE_ASSIST
		direction_Sign.visible = true
		print("当前模式：鼠标瞄准")
	else:
		player_current_aim_mode = AimMode_Type.AUTO_NEAREST
		direction_Sign.visible = false
		print("当前模式：自动瞄准")

# [未完成/预留] 将对象组重新补位排序
func _updata_all_enter_Character():
	pass
	#for i in range(enter_Character.size())
#endregion
