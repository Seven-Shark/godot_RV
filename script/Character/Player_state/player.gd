extends CharacterBase
class_name Player

#鼠标辅助瞄准的参数
const ASSIST_ANGLE = 90.0 #辅助瞄准角度
const ASSIST_RANGE = 250.0 #辅助瞄准
const ASSIST_RANGE_SQ = ASSIST_RANGE * ASSIST_RANGE #


enum AimMode_Type {
	AUTO_NEAREST,#自动瞄准
	MOUSE_ASSIST #鼠标辅助
}
#默认瞄准模式
var player_current_aim_mode = AimMode_Type.MOUSE_ASSIST

#初始化
func _init() -> void:
	character_type = CharacterType.PLAYER
	#设置该角色追踪的目标
	target_types = [CharacterType.ITEM,CharacterType.ENEMY]

#update
func _process(_delta):
	
	#根据移动方向改变图片朝向
	_update_facing_direction()

	#获取不同瞄准模式下的目标
	var final_target:CharacterBase = null
	#获取实时鼠标的世界位置
	var mouse_pos = get_global_mouse_position()
	#确定不同瞄准模式下的目标
	final_target = _get_target_by_mode(mouse_pos)
	#将锁定目标
	_update_target_locking(final_target)
	#不同模式下，是否显示指示器
	_update_DirectionSign_Visible(mouse_pos)
	#鼠标辅助模式下，画出范围
	queue_redraw()

#切换瞄准模式
func toggle_aim_mode():
	if player_current_aim_mode == AimMode_Type.AUTO_NEAREST:
		player_current_aim_mode = AimMode_Type.MOUSE_ASSIST
		direction_Sign.visible = true
		print("当前模式：鼠标瞄准")
	else:
		player_current_aim_mode = AimMode_Type.AUTO_NEAREST
		direction_Sign.visible = false
		print("当前模式：自动瞄准")

#用于控制不同瞄准模式下，显示指示器的逻辑
func _update_DirectionSign_Visible(mouse_pos:Vector2):
	
	if not is_instance_valid(direction_Sign):
		return
		
	if is_instance_valid(direction_Sign):
		match player_current_aim_mode:
			#【自动模式】：有目标才显示，没目标隐藏
			AimMode_Type.AUTO_NEAREST:
				if is_instance_valid(current_target):
					direction_Sign.visible = true
					Target_Lock_On(current_target)
				else:
					direction_Sign.visible = false
					Target_Lock_On(null)
			#【鼠标模式】：箭头常驻
			AimMode_Type.MOUSE_ASSIST:
				direction_Sign.visible = true
				if is_instance_valid(current_target):
					Target_Lock_On(current_target)
				else:
					_look_at_mouse(mouse_pos)

#根据不同的瞄准模式来获取追踪目标
func _get_target_by_mode(mouse_pos:Vector2) -> CharacterBase:
	match player_current_aim_mode:
		AimMode_Type.AUTO_NEAREST:
			#自动模式：直接获取最近的目标
			return get_closest_target()
		AimMode_Type.MOUSE_ASSIST:
			#鼠标模式：获取鼠标方位的最近的目标
			return get_mouse_assist_target(mouse_pos)
	return null

#锁定目标，和当目标丢失后的处理
func _update_target_locking(new_target: CharacterBase):
	# 如果找到了新目标，且和当前手里的不一样 -> 切换锁定
	if new_target and new_target != current_target:
		print("锁定目标：", new_target.name)
		current_target = new_target
	# 如果没找到新目标，且当前手里还锁着一个有效目标 -> 丢失目标
	elif not new_target and is_instance_valid(current_target):
		print("【目标丢失】解除锁定")
		current_target = null

#鼠标瞄准辅助攻击逻辑
func get_mouse_assist_target(mouse_position:Vector2) -> CharacterBase:
	#确认瞄准中心方向：玩家到鼠标方向向量
	var self_pos = global_position
	var to_mouse_dir = (mouse_position - self_pos).normalized()
	var closest_assist_target:CharacterBase = null
	var closest_dist_sq = INF
	
	#扇形一半角度（弧度制）
	var half_angle_rad = deg_to_rad(ASSIST_ANGLE / 2.0)
	var target_array:Array = detection_Area.get_overlapping_bodies()
	
	#必须是 CharacterBase, 不是自己, 且是该角色要追踪的类型
	for body in target_array:
		if body is CharacterBase and body != self and target_types.has(body.character_type):
			var target_vec = body.global_position - self_pos
			var dist_sq = target_vec.length_squared()
			
			# 条件 A: 距离在辅助范围内 (150px)
			if dist_sq <= ASSIST_RANGE_SQ:
				
				# 条件 B: 角度在鼠标指向的扇形范围内 (30度)
				# angle_to 返回两个向量的夹角弧度
				if abs(to_mouse_dir.angle_to(target_vec)) <= half_angle_rad:
					
					# 条件 C: 在满足 A/B 的所有目标中，找出距离最近的那个
					if dist_sq < closest_dist_sq:
						closest_dist_sq = dist_sq
						closest_assist_target = body
						
	return closest_assist_target

#当鼠标模式下，未锁定目标时，箭头指向鼠标
func _look_at_mouse(mouse_position:Vector2):
	if is_instance_valid(direction_Sign):
		var direction_vector = mouse_position - global_position
		direction_Sign.rotation = direction_vector.angle()
		direction_Sign.visible = true

#在鼠标辅助准模式下，画两条指示范围的线
func _draw():
	if player_current_aim_mode == AimMode_Type.MOUSE_ASSIST:
		var mouse_pos = get_global_mouse_position()
		var to_mouse = (mouse_pos - global_position).normalized()
		var angle = deg_to_rad(ASSIST_ANGLE / 2.0)
		draw_line(Vector2.ZERO , to_mouse.rotated(angle) * ASSIST_RANGE,Color(1,0,0,0.5),2)
		draw_line(Vector2.ZERO , to_mouse.rotated(-angle) * ASSIST_RANGE,Color(1,0,0,0.5),2)

#处理角色朝向的逻辑，根据不同瞄准模式切换
func _update_facing_direction():
	var look_at_point = null
	
	#根据瞄准模式，决定角色该盯着哪里看
	match player_current_aim_mode:
		AimMode_Type.MOUSE_ASSIST:
			look_at_point = get_global_mouse_position()
			
		AimMode_Type.AUTO_NEAREST:
			if is_instance_valid(current_target):
				look_at_point = current_target.global_position
			else :
				look_at_point = null
	
	#执行翻转的逻辑
	if look_at_point != null:
		var direction_factor = -1 if flipped_horizontal  else 1
		
		if look_at_point.x > global_position.x:
			sprite.scale.x = direction_factor
		elif look_at_point.x < global_position.x:
			sprite.scale.x = -direction_factor
	else :
		Turn()

#将对象组重新补位排序（未完成版，暂未用到）
func _updata_all_enter_Character():
	pass
	#for i in range(enter_Character.size())
