extends Node
class_name ResourceVisuals

## 资源表现控制器 (ResourceVisuals) - 子节点组件
##
## 职责：
## 1. [动画]：处理生成时的抛物线、挤压拉伸动画。
## 2. [运动]：集成了原 GravityReceiver 的功能，处理被吸向目标的位移。
## 3. [通用性]：可以复用在任何 Node2D 父节点上。

#region 1. 动画配置
@export_group("Launch Animation")
@export var jump_height: float = 40.0           ## 跳跃高度
@export var stretch_ratio: Vector2 = Vector2(1.2, 1.2) ## 拉伸比例
@export var squash_ratio: Vector2 = Vector2(0.9, 0.7)  ## 挤压比例
@export var anim_duration_min: float = 0.4      ## 动画时长下限
@export var anim_duration_max: float = 0.6      ## 动画时长上限
#endregion

#region 2. 吸附飞行配置 (原 GravityReceiver)
@export_group("Absorb Movement")
@export var acceleration: float = 4500.0   ## 飞行加速度
@export var collect_distance: float = 20.0 ## 收集判定距离
#endregion

#region 3. 内部引用与状态
var parent_node: Node2D            ## 父节点引用
var sprite_node: Node2D            ## 视觉精灵引用
var attract_target: Node2D = null  ## 吸引目标
var current_speed: float = 0.0     ## 当前吸附速度
var is_absorbing: bool = false     ## 是否正在执行吸附逻辑
#endregion

#region 生命周期
func _ready() -> void:
	parent_node = get_parent() as Node2D
	if not parent_node:
		push_error("ResourceVisuals: 必须挂载在 Node2D 或其子类下！")
		return
	
	# 自动查找 Sprite，增强通用性
	sprite_node = _find_sprite_node()
	
	# 连接父节点的信号 (如果父节点有这些信号的话)
	if parent_node.has_signal("launch_requested"):
		parent_node.connect("launch_requested", _on_launch_requested)
	
	if parent_node.has_signal("absorb_requested"):
		parent_node.connect("absorb_requested", _on_absorb_requested)

func _physics_process(delta: float) -> void:
	# 只有在吸附状态下才运行物理位移逻辑
	if is_absorbing:
		_process_absorb_movement(delta)
#endregion

#region 逻辑实现 - 1. 爆出动画

## [回调] 响应父节点的爆出请求
func _on_launch_requested(start_pos: Vector2, target_pos: Vector2):
	parent_node.global_position = start_pos
	
	var duration = randf_range(anim_duration_min, anim_duration_max)
	var tween = create_tween()
	
	# 1. 整体位移
	tween.tween_property(parent_node, "global_position", target_pos, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. 视觉形变 (如果有 Sprite)
	if sprite_node:
		var base_scale = sprite_node.scale # 记录原始缩放
		sprite_node.scale = Vector2.ZERO   # 初始设为0
		
		# 并行执行跳跃和形变
		_animate_jump(duration)
		_animate_squash(duration, base_scale)
	
	await tween.finished
	
	# 动画结束，通知父节点开启物理检测
	if not is_absorbing and parent_node.has_method("enable_pickup_detection"):
		parent_node.enable_pickup_detection()

## [内部] 跳跃动画 (Y轴)
func _animate_jump(duration: float):
	if not sprite_node: return
	var t = create_tween()
	t.tween_property(sprite_node, "position:y", -jump_height, duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(sprite_node, "position:y", 0.0, duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## [内部] 挤压拉伸动画
func _animate_squash(duration: float, base_scale: Vector2):
	if not sprite_node: return
	var t = create_tween()
	# 变大拉伸
	t.tween_property(sprite_node, "scale", base_scale * stretch_ratio, duration * 0.7)
	# 落地挤压
	t.chain().tween_property(sprite_node, "scale", base_scale * squash_ratio, 0.1)
	# 恢复
	t.chain().tween_property(sprite_node, "scale", base_scale, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

#endregion

#region 逻辑实现 - 2. 吸附飞行 (整合了 GravityReceiver)

## [回调] 响应父节点的吸附请求
func _on_absorb_requested(target: Node2D):
	if is_absorbing: return
	
	is_absorbing = true
	attract_target = target
	current_speed = 100.0 # 初始速度

	# 可以在这里加一些被吸起的特效，比如变色
	if sprite_node:
		var t = create_tween()
		t.tween_property(sprite_node, "modulate", Color(1.5, 1.5, 1.5), 0.2) # 变亮

## [每帧] 计算飞行位移
func _process_absorb_movement(delta: float):
	if not is_instance_valid(parent_node) or not is_instance_valid(attract_target):
		queue_free() # 目标丢失，组件失效
		return

	# 1. 计算方向
	var direction = (attract_target.global_position - parent_node.global_position).normalized()
	
	# 2. 加速
	current_speed += acceleration * delta
	
	# 3. 移动父节点
	parent_node.global_position += direction * current_speed * delta
	
	# 4. 距离检测
	var dist = parent_node.global_position.distance_to(attract_target.global_position)
	if dist <= collect_distance:
		_finish_collect()

## [内部] 触发收集结算
func _finish_collect():
	if parent_node.has_method("collect_success"):
		parent_node.collect_success()
	else:
		# 容错：如果父节点没有结算方法，直接销毁
		parent_node.queue_free()

#endregion

#region 辅助功能
## [通用] 自动查找 Sprite 节点
func _find_sprite_node() -> Node2D:
	# 先找父节点的直接子节点
	var s = parent_node.get_node_or_null("Sprite2D")
	if not s: s = parent_node.get_node_or_null("AnimatedSprite2D")
	
	# 如果没找到，遍历查找
	if not s:
		for child in parent_node.get_children():
			if child is Sprite2D or child is AnimatedSprite2D:
				return child
	return s
#endregion
