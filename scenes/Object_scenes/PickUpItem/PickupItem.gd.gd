extends RigidBody2D
class_name PickupItem

## 掉落物单体类 (PickupItem)
## ... (头部注释保持不变) ...

#region 配置常量
const TARGET_LAYER_VALUE: int = 8 
#endregion

#region 渲染层级配置
@export_group("Rendering")
@export var target_z_index: int = -1 
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

#region 吸附逻辑配置 (新增)
var is_being_absorbed: bool = false   ## [内部] 是否正在被引力枪吸附
var attract_target: Node2D = null     ## [内部] 吸附的目标 (通常是玩家)
var current_fly_speed: float = 0.0    ## [内部] 当前飞行速度
const ABSORB_ACCELERATION: float = 4500.0 ## [配置] 吸附飞行加速度 (越大越快)
const ABSORB_COLLECT_DIST: float = 20.0   ## [配置] 距离多近时算收集成功
#endregion

#region 生命周期

func _ready() -> void:
	_init_physics_state()
	z_index = target_z_index

func _physics_process(delta: float) -> void:
	# 【新增】处理吸附飞行逻辑
	if is_being_absorbed:
		_process_absorb_movement(delta)

## 初始化刚体的物理参数
func _init_physics_state():
	freeze = true 
	collision_layer = 0
	collision_mask = 0
	gravity_scale = 0.0 
	lock_rotation = true
	y_sort_enabled = true
#endregion

#region 核心功能

## 执行抛物线爆出动画
func launch(start_pos: Vector2, target_pos: Vector2):
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
	
	# 如果在落地前就被吸走了，就不要执行落地逻辑了
	if not is_being_absorbed:
		_enable_pickup_detection()

## 【新增】开始被引力吸附
## 由武器脚本调用
func start_absorbing(target: Node2D):
	if is_being_absorbed: return # 防止重复调用
	
	is_being_absorbed = true
	attract_target = target
	current_fly_speed = 100.0 # 给一个初始速度，避免起步太慢
	
	# 关闭碰撞，防止飞行过程中卡在墙上或被其他东西挡住
	collision_layer = 0
	collision_mask = 0
	
	# 确保处于冻结状态 (以防万一)
	freeze = true
	
	# 可选：播放一个被吸起的音效
	# print("资源被吸起: ", name)

#endregion

#region 内部辅助逻辑

## 【新增】处理吸附飞行的每帧逻辑
func _process_absorb_movement(delta: float):
	if not is_instance_valid(attract_target):
		# 如果目标(玩家)没了，就自毁或者掉落，这里简单处理为自毁
		queue_free()
		return

	# 1. 计算方向
	var direction = (attract_target.global_position - global_position).normalized()
	
	# 2. 计算速度 (加速度公式：v = v0 + at)
	# 这种持续增加速度的方式，自然就是“由慢到快”的效果
	current_fly_speed += ABSORB_ACCELERATION * delta
	
	# 3. 移动位置
	global_position += direction * current_fly_speed * delta
	
	# 4. 距离检测 (收集判定)
	var distance = global_position.distance_to(attract_target.global_position)
	if distance <= ABSORB_COLLECT_DIST:
		_collect_resource()

## 【新增】资源收集逻辑
func _collect_resource():
	# 这里应该调用背包系统的接口，比如：
	# InventoryManager.add_item(item_id, quantity)
	# 暂时先打印日志并销毁
	# print("获得资源: ", name)
	
	queue_free()

## [内部] 动画结束后，仅开启检测
func _enable_pickup_detection():
	# 如果已经被吸附了，就不再开启检测
	if is_being_absorbed: return
	
	collision_layer = TARGET_LAYER_VALUE
	collision_mask = 0
	freeze = true 

## [内部] 处理 Sprite 的跳跃动画
func _animate_jump(sprite: Node2D, duration: float):
	var height_tween = create_tween()
	height_tween.tween_property(sprite, "position:y", -jump_height, duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	height_tween.chain().tween_property(sprite, "position:y", 0.0, duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## [内部] 处理 Sprite 的缩放动画
func _animate_squash_stretch(sprite: Node2D, duration: float, base_scale: Vector2):
	sprite.scale = base_scale * start_scale_ratio
	var scale_tween = create_tween()
	scale_tween.tween_property(sprite, "scale", base_scale * stretch_ratio, duration * 0.7)
	scale_tween.chain().tween_property(sprite, "scale", base_scale * squash_ratio, 0.1)
	scale_tween.chain().tween_property(sprite, "scale", base_scale, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

#endregion
