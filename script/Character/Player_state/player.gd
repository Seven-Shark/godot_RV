extends CharacterBase
class_name Player

#var enter_Character : Array[CharacterBase] = []
#var current_target : CharacterBase = null



func _init() -> void:
	character_type = CharacterType.PLAYER
	#设置该角色追踪的目标
	target_types = [CharacterType.ITEM,CharacterType.ENEMY]


func _process(_delta):
	
	#根据移动方向改变图片朝向
	Turn()
	
	#寻找范围内最近的目标，并打印出来
	var nearest_target = get_closest_target()
	#var current_target = current_target.name if current_target else ""
	if nearest_target and nearest_target != current_target:
		print("找到最近的目标:",nearest_target.name)
		current_target = nearest_target
	elif not nearest_target and current_target:
		print("[目标丢失] 目标 ",current_target.name,"已离开或不再是最近目标。")
		current_target = null
		
	#朝向范围内最近的对象
	Target_Lock_On(nearest_target)


#将对象组重新补位排序（未完成版，暂未用到）
func _updata_all_enter_Character():
	pass
	#for i in range(enter_Character.size())
	
	
#endregion
