extends CharacterBase
class_name Player

#var enter_Character : Array[CharacterBase] = []
#var current_target : CharacterBase = null
enum AimMode_Type {
	AUTO_NEAREST,
	MOUSE_ASSIST
}
var player_current_aim_mode = AimMode_Type.AUTO_NEAREST


func _init() -> void:
	character_type = CharacterType.PLAYER
	#设置该角色追踪的目标
	target_types = [CharacterType.ITEM,CharacterType.ENEMY]


func _process(_delta):
	
	#根据移动方向改变图片朝向
	Turn()
	
	#获取不同瞄准模式下的目标
	var final_target:CharacterBase = null
	#获取实时鼠标的世界位置
	var mouse_pos = get_global_mouse_position()
	
	#确定不同瞄准模式下的目标
	match player_current_aim_mode:
		AimMode_Type.AUTO_NEAREST:
			#自动模式：直接获取最近的目标
			final_target = get_closest_target()
		AimMode_Type.MOUSE_ASSIST:
			#鼠标模式：获取鼠标方位的最近的目标
			final_target = get_mouse_assist_target(mouse_pos)
	
	#s更新current_target的状态（用于单词输出和攻击方向）
	var current_target_name = current_target.name if is_instance_valid(current_target) else ""
	var final_target_name = final_target.name if  is_instance_valid(final_target) else ""
	
	if final_target and final_target_name != current_target_name:
		print("锁定目标：",final_target.name)
		current_target = final_target
	elif not final_target and is_instance_valid(current_target):
		print("【目标丢失】解除锁定")
		current_target = null
	
	#箭头朝向逻辑：
	if player_current_aim_mode == AimMode_Type.MOUSE_ASSIST and current_target == null:
		_look_at_mouse(mouse_pos)
	else:
		Target_Lock_On(current_target)

	if is_instance_valid(direction_Sign):
		match player_current_aim_mode:
			AimMode_Type.AUTO_NEAREST:
				if is_instance_valid(current_target):
					direction_Sign.visible = true
					Target_Lock_On(current_target)
				else:
					direction_Sign.visible = false
			AimMode_Type.MOUSE_ASSIST:
				direction_Sign.visible = true
				
				if is_instance_valid(current_target):
					Target_Lock_On(current_target)
				else:
					_look_at_mouse(mouse_pos)




	
	##寻找范围内最近的目标，并打印出来
	#var nearest_target = get_closest_target()
	##var current_target = current_target.name if current_target else ""
	#if nearest_target and nearest_target != current_target:
		#print("找到最近的目标:",nearest_target.name)
		#current_target = nearest_target
	#elif not nearest_target and current_target:
		#print("[目标丢失] 目标 ",current_target.name,"已离开或不再是最近目标。")
		#current_target = null
		#
	
		
		
		
	##朝向范围内最近的对象
	#Target_Lock_On(nearest_target)

#新增方法：当鼠标模式下，未锁定目标时，箭头指向鼠标
func _look_at_mouse(mouse_position:Vector2):
	if is_instance_valid(direction_Sign):
		var direction_vector = mouse_position - global_position
		direction_Sign.rotation = direction_vector.angle()
		direction_Sign.visible = true
		

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

#将对象组重新补位排序（未完成版，暂未用到）
func _updata_all_enter_Character():
	pass
	#for i in range(enter_Character.size())
	
	
#endregion
