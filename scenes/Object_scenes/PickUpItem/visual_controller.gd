extends Node
class_name VisualController

## 视觉控制器 (VisualController)
## 职责：统一管理所有动画（震动、抛物线、吸附飞行、悬停拉伸）。
## 智能适配：根据父节点 entity_type 自动选择行为。

#region 配置参数
@export_group("Prop Animation")
@export var shake_strength: float = 20.0 ## 受击震动幅度
@export var hover_lift_height: float = 20.0 ## 引力悬停时的拔高高度
@export var hover_shake_speed: float = 80.0 ## 悬停时的抖动速度

@export_group("Resource Animation")
@export var jump_height: float = 40.0 ## 爆出高度
@export var absorb_accel: float = 4500.0 ## 吸附加速度
@export var collect_dist: float = 20.0 ## 收集距离
#endregion

#region 内部变量
var parent: WorldEntity
var sprite: Node2D
var current_tween: Tween

# --- 状态：物件悬停 (Prop) ---
var is_hovering: bool = false
var hover_timer: float = 0.0
var original_pos_local: Vector2 = Vector2.ZERO ## 记录 Sprite 原始局部坐标
var original_scale: Vector2 = Vector2.ONE ## Sprite 原始缩放

# --- 状态：资源吸附 (Resource) ---
var absorb_target: Node2D
var absorb_speed: float = 0.0
var is_absorbing: bool = false
#endregion

#region 生命周期
## 初始化控制器，查找组件并连接信号
func _ready() -> void:
	parent = get_parent() as WorldEntity
	if not parent:
		push_error("VisualController: 父节点必须是 WorldEntity")
		return
	
	# 1. 查找 Sprite 并记录原始位置和缩放
	sprite = _find_sprite()
	if sprite:
		original_pos_local = sprite.position
		original_scale = sprite.scale # 记录编辑器里设置的缩放值
	
	# 2. 根据父节点类型，订阅不同信号
	match parent.entity_type:
		# [核心修复] 将 NEST 加入此处，让巢穴也能响应受击和死亡动画
		WorldEntity.EntityType.PROP, WorldEntity.EntityType.NEST:
			parent.visuals_hit_requested.connect(_on_hit)
			parent.visuals_death_requested.connect(_on_death)
			parent.visuals_gravity_process.connect(_on_prop_gravity_process)
			parent.visuals_recover_requested.connect(_on_recover)
			parent.visuals_launch_requested.connect(_on_launch)
			
		WorldEntity.EntityType.RESOURCE:
			parent.visuals_launch_requested.connect(_on_launch)
			parent.visuals_absorb_requested.connect(_on_absorb_start)
			
		WorldEntity.EntityType.HEAVY:
			parent.visuals_hit_requested.connect(_on_hit)
			parent.visuals_recover_requested.connect(_on_recover)

## 物理帧处理，用于更新持续性的动画逻辑（吸附移动、悬停抖动）
func _physics_process(delta: float) -> void:
	# 资源：飞向玩家
	if is_absorbing:
		_process_absorb_movement(delta)
	
	# 物件：悬停抖动
	if is_hovering and sprite:
		_process_hover_shake(delta)
#endregion

#region 逻辑 A: 物件动画 (Prop/Heavy/Nest)

## [动画] 处理受击时的震动效果
func _on_hit(dir: Vector2):
	if not sprite: return
	if is_hovering:
		_play_flash_white()
		return

	if current_tween: current_tween.kill()
	current_tween = create_tween()
	var offset = dir * shake_strength
	
	# 弹性震动
	current_tween.tween_property(sprite, "position", original_pos_local + offset, 0.05)
	current_tween.tween_property(sprite, "position", original_pos_local, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	_play_flash_white()

## [动画] 处理死亡时的缩小和消失效果
func _on_death():
	var t = create_tween()
	if sprite:
		t.tween_property(sprite, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK)
		t.parallel().tween_property(sprite, "modulate:a", 0.0, 0.2)
	
	await t.finished
	if is_instance_valid(parent):
		parent.queue_free()

## [动画] 处理被引力枪吸起时的悬停效果 (Enter Hover)
func _on_prop_gravity_process(_attractor_pos: Vector2):
	if is_hovering: return
	
	is_hovering = true
	hover_timer = 0.0
	
	if current_tween: current_tween.kill()
	current_tween = create_tween()
	
	var lift_pos = original_pos_local + Vector2.UP * hover_lift_height
	
	current_tween.set_parallel(true)
	# 1. 向上拔起
	current_tween.tween_property(sprite, "position", lift_pos, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 2. 拉伸变细基于 original_scale 计算
	current_tween.tween_property(sprite, "scale", original_scale * Vector2(0.8, 1.2), 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 3. 变蓝
	current_tween.tween_property(sprite, "modulate", Color(0.5, 1.5, 2.0, 1.0), 0.3)

## [每帧] 处理悬停状态下的持续上下抖动
func _process_hover_shake(delta: float):
	hover_timer += delta * hover_shake_speed
	var shake_offset = Vector2(sin(hover_timer) * 1.5, 0)
	var lift_pos = original_pos_local + Vector2.UP * hover_lift_height
	sprite.position = lift_pos + shake_offset

## [动画] 处理从悬停状态恢复到正常状态 (Exit Hover)
func _on_recover():
	if not is_hovering and parent.entity_type != WorldEntity.EntityType.HEAVY: return
	
	is_hovering = false
	if not sprite: return
	
	if current_tween: current_tween.kill()
	current_tween = create_tween()
	
	current_tween.set_parallel(true)
	# 弹回原位
	current_tween.tween_property(sprite, "position", original_pos_local, 0.4)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# 恢复缩放
	current_tween.tween_property(sprite, "scale", original_scale, 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# 恢复颜色
	current_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	current_tween.tween_property(sprite, "rotation", 0.0, 0.4)

## [辅助] 播放受击时的瞬间闪白特效
func _play_flash_white():
	var t = create_tween()
	sprite.modulate = Color(2, 2, 2)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.2)

#endregion

#region 逻辑 B: 资源动画 (Resource)

## [动画] 处理资源爆出时的抛物线运动
func _on_launch(start: Vector2, end: Vector2):
	parent.global_position = start
	var duration = randf_range(0.4, 0.6)
	var t = create_tween()
	
	# 1. 整体抛物线位移
	t.tween_property(parent, "global_position", end, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. Sprite 跳跃与形变
	if sprite:
		sprite.scale = Vector2.ZERO # 初始为0，产生从无到有的效果
		var t_jump = create_tween()
		
		# 跳跃 (Y轴)
		t_jump.tween_property(sprite, "position:y", -jump_height, duration * 0.5).set_ease(Tween.EASE_OUT)
		t_jump.chain().tween_property(sprite, "position:y", 0.0, duration * 0.5).set_ease(Tween.EASE_IN)
		
		# 挤压拉伸
		var t_scale = create_tween()
		t_scale.tween_property(sprite, "scale", original_scale * 1.2, duration * 0.5) # 变大一点
		t_scale.chain().tween_property(sprite, "scale", original_scale, 0.2) # 恢复原大小
	
	await t.finished
	if not is_absorbing and is_instance_valid(parent):
		parent.enable_pickup_detection()

## [动画] 处理资源开始被吸附时的状态切换
func _on_absorb_start(target: Node2D):
	is_absorbing = true
	absorb_target = target
	absorb_speed = 100.0
	
	if sprite:
		var t = create_tween()
		t.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.0), 0.2) # 变亮

## [每帧] 处理资源在吸附过程中的飞行位移逻辑
func _process_absorb_movement(delta: float):
	if not is_instance_valid(parent) or not parent.is_inside_tree() or not is_instance_valid(absorb_target):
		if is_instance_valid(parent): parent.queue_free()
		return
	
	var dir = (absorb_target.global_position - parent.global_position).normalized()
	absorb_speed += absorb_accel * delta
	parent.global_position += dir * absorb_speed * delta
	
	if parent.global_position.distance_to(absorb_target.global_position) <= collect_dist:
		parent.collect_success()
#endregion

#region 辅助功能
## 查找父节点下的 Sprite2D 或 AnimatedSprite2D 组件
func _find_sprite() -> Node2D:
	for child in parent.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null
#endregion
