extends RigidBody2D
class_name PickupItem

## 掉落物单体类 (PickupItem)
## ... (头部注释保持不变)

#region 配置常量
const TARGET_LAYER_VALUE: int = 16 
#endregion

#region 物理与重叠配置 (新增)
@export_group("Physics Settings")
## 两个资源中心点的最小间距
## 物理引擎会确保两个物体的中心距离不小于这个值
## 如果这个值小于图片的尺寸，资源就会在视觉上产生重叠
@export var min_center_distance: float = 15.0 
#endregion

#region 动画配置
@export_group("Animation Settings")
@export var jump_height: float = 40.0         
@export var start_scale_ratio: Vector2 = Vector2.ZERO  
@export var stretch_ratio: Vector2 = Vector2(1.2, 1.2) 
@export var squash_ratio: Vector2 = Vector2(0.9, 0.7)  
@export var anim_duration_min: float = 0.4    
@export var anim_duration_max: float = 0.6    
#endregion

#region 生命周期
func _ready() -> void:
	_init_physics_state()
	_update_collision_shape_size() # 【新增】初始化碰撞体大小

func _init_physics_state():
	freeze = true 
	collision_layer = 0
	collision_mask = 0
	linear_damp = 5.0 
	gravity_scale = 0.0 
	lock_rotation = true
#endregion

#region 核心功能
func launch(start_pos: Vector2, target_pos: Vector2):
	# ... (launch 函数内容保持不变) ...
	# 直接复制之前的 launch 代码即可
	global_position = start_pos
	
	var sprite_node = get_node_or_null("Sprite2D")
	if not sprite_node: return

	var original_scale = sprite_node.scale 

	var tween = create_tween()
	var duration = randf_range(anim_duration_min, anim_duration_max)
	
	tween.tween_property(self, "global_position", target_pos, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	_animate_jump(sprite_node, duration)
	_animate_squash_stretch(sprite_node, duration, original_scale)

	await tween.finished
	_restore_physics_state()
#endregion

#region 内部辅助逻辑
# ... (_animate_jump 和 _animate_squash_stretch 保持不变) ...

func _animate_jump(sprite: Node2D, duration: float):
	var height_tween = create_tween()
	height_tween.tween_property(sprite, "position:y", -jump_height, duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	height_tween.chain().tween_property(sprite, "position:y", 0.0, duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _animate_squash_stretch(sprite: Node2D, duration: float, base_scale: Vector2):
	sprite.scale = base_scale * start_scale_ratio
	var scale_tween = create_tween()
	scale_tween.tween_property(sprite, "scale", base_scale * stretch_ratio, duration * 0.7)
	scale_tween.chain().tween_property(sprite, "scale", base_scale * squash_ratio, 0.1)
	scale_tween.chain().tween_property(sprite, "scale", base_scale, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _restore_physics_state():
	collision_layer = TARGET_LAYER_VALUE
	collision_mask = TARGET_LAYER_VALUE 
	freeze = false

# 【新增】根据配置动态调整碰撞体大小
func _update_collision_shape_size():
	var collision_node = get_node_or_null("CollisionShape2D")
	if not collision_node:
		push_warning("PickupItem: 找不到 CollisionShape2D，无法调整间距。")
		return
		
	# 确保使用的是 CircleShape2D (圆形碰撞体最适合做挤压)
	if collision_node.shape is CircleShape2D:
		# 为了不影响其他资源文件，我们应该复制一份 shape (使其唯一)
		# 只有当你同一个 tscn 文件被实例化多次，且你想让它们有不同的半径时才需要 duplicate
		# 但为了保险起见，建议加上
		var new_shape = collision_node.shape.duplicate()
		
		# 半径 = 中心间距的一半
		# 因为两个物体相撞，是 半径A + 半径B >= 间距
		new_shape.radius = min_center_distance / 2.0
		
		collision_node.shape = new_shape
	else:
		push_warning("PickupItem: 碰撞体形状不是 CircleShape2D，间距配置可能不准确。")
#endregion
