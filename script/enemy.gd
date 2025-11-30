extends CharacterBase
class_name Enemy

var current_tag:int = 0

func _init() -> void:
	character_type = CharacterType.ENEMY

func _ready() -> void:
	pass
	
func set_target_tag(tag: int) -> void:
	current_tag = tag
