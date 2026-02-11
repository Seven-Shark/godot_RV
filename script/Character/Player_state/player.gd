extends CharacterBase
class_name Player

## Player.gd
## 职责：处理玩家特有的输入交互、瞄准模式和视觉反馈。

#region 瞄准配置
const ASSIST_ANGLE = 90.0   ## 辅助瞄准角度
const ASSIST_RANGE = 250.0  ## 辅助瞄准距离
const ASSIST_RANGE_SQ = ASSIST_RANGE * ASSIST_RANGE
#endregion

#region 枚举与变量
enum AimMode_Type {
	AUTO_NEAREST, ## 自动锁定最近
	MOUSE_ASSIST  ## 鼠标辅助扇形
}
var player_current_aim_mode: AimMode_Type = AimMode_Type.MOUSE_ASSIST
#endregion

#region 生命周期
func _init() -> void:
	character_type = CharacterType.PLAYER
	target_types = [CharacterType.ITEM, CharacterType.ENEMY]

func _process(_delta: float) -> void:
	# 1. 视觉朝向
	_update_facing_direction()

	# 2. 获取鼠标位置
	var mouse_pos = get_global_mouse_position()
	
	# 3. 获取目标
	var final_target: CharacterBase = _get_target_by_mode(mouse_pos)
	
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

#region 目标获取逻辑
func _get_target_by_mode(mouse_pos: Vector2) -> CharacterBase:
	match player_current_aim_mode:
		AimMode_Type.AUTO_NEAREST:
			return get_closest_target()
		AimMode_Type.MOUSE_ASSIST:
			return get_mouse_assist_target(mouse_pos)
	return null

func get_mouse_assist_target(mouse_position: Vector2) -> CharacterBase:
	var self_pos = global_position
	var to_mouse_dir = (mouse_position - self_pos).normalized()
	var closest_assist_target: CharacterBase = null
	var closest_dist_sq = INF
	
	var half_angle_rad = deg_to_rad(ASSIST_ANGLE / 2.0)
	var target_array: Array = detection_Area.get_overlapping_bodies()
	
	for body in target_array:
		if body is CharacterBase and body != self and target_types.has(body.character_type):
			var target_vec = body.global_position - self_pos
			var dist_sq = target_vec.length_squared()
			
			if dist_sq <= ASSIST_RANGE_SQ:
				if abs(to_mouse_dir.angle_to(target_vec)) <= half_angle_rad:
					if dist_sq < closest_dist_sq:
						closest_dist_sq = dist_sq
						closest_assist_target = body
						
	return closest_assist_target

func _update_target_locking(new_target: CharacterBase) -> void:
	if new_target and new_target != current_target:
		# print("锁定目标：", new_target.name)
		current_target = new_target
	elif not new_target and is_instance_valid(current_target):
		# print("【目标丢失】解除锁定")
		current_target = null
#endregion

#region 视觉表现
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

#region 接口
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
