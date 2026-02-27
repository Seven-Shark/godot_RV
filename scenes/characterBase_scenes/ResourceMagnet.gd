extends Area2D
class_name ResourceMagnet

@export var is_active: bool = true 
@export var target_node: Node2D 

func _ready() -> void:
	if not target_node:
		target_node = get_parent()

func _input(event: InputEvent) -> void:
	# [修改] 使用全局输入管理器判断开关指令
	if GameInputEvents.is_toggle_magnet_event(event):
		is_active = !is_active
		print(">>> [Magnet] 自动吸附状态: ", "开启" if is_active else "关闭")

func _physics_process(_delta: float) -> void:
	if not is_active: return
	position.x = 0.001 if Engine.get_physics_frames() % 2 == 0 else -0.001
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body is WorldEntity:
			if body.entity_type == WorldEntity.EntityType.RESOURCE:
				body.start_absorbing(target_node)
