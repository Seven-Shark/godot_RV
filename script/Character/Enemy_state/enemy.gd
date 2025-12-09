extends CharacterBase
class_name Enemy

var current_tag:int = 0

func _init() -> void:
	character_type = CharacterType.ENEMY
	target_types = [CharacterType.PLAYER]

func _ready() -> void:
	pass
	
func _process(_delta) -> void:
	
	#跟角色一样，识别最近的玩家，然后箭头转向玩家
	var nearest_target = get_closest_target()
	if nearest_target and nearest_target != current_target:
		print("敌人发现了我:",nearest_target.name)
		current_target = nearest_target
	elif not nearest_target and current_target:
		print("[目标丢失] 目标 ",current_target.name,"已离开或不再是最近目标。")
		current_target = null
	Target_Lock_On(nearest_target)
	
func set_target_tag(tag: int) -> void:
	current_tag = tag
	
func clear_target_tag() -> void:
	current_tag = 0
