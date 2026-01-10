extends RigidBody2D
class_name PickupItem

## 掉落物单体类 (PickupItem)
##
## 负责处理资源掉落时的表现逻辑：
## 1. 生成时暂时冻结物理，由 Tween 动画接管位置（抛物线效果）。
## 2. 动画期间关闭碰撞，防止飞出屏幕或与玩家发生不必要的碰撞。
## 3. 落地后解冻物理并恢复碰撞，利用刚体特性实现资源间的自然挤压。

#region 配置常量
# 目标碰撞层级值 (对应 Items 层)
# 假设 Items 层在第 5 层: 2^(5-1) = 16
const TARGET_LAYER_VALUE: int = 16 
#endregion

#region 物理与重叠配置 (新增)
@export_group("Physics Settings")
## 两个资源中心点的最小间距
## 物理引擎会确保两个物体的中心距离不小于这个值。
## 原理：我们将碰撞体的半径设为这个值的一半。
## 如果这个值小于图片的尺寸，两个资源就会在视觉上产生重叠（虽然物理上它们已经贴在一起了）。
@export var min_center_distance: float = 15.0 
#endregion

#region 动画配置
@export_group("Animation Settings")
@export var jump_height: float = 40.0         ## 跳起高度
@export var start_scale_ratio: Vector2 = Vector2.ZERO  ## 初始缩放 (0,0 表示从无到有)
@export var stretch_ratio: Vector2 = Vector2(1.2, 1.2) ## 弹出时的拉伸比例
@export var squash_ratio: Vector2 = Vector2(0.9, 0.7)  ## 落地时的压扁比例
@export var anim_duration_min: float = 0.4    ## 动画最短时长
@export var anim_duration_max: float = 0.6    ## 动画最长时长
#endregion

#region 生命周期

## 节点准备就绪时调用
func _ready() -> void:
	# 1. 初始化物理状态（冻结、关闭碰撞）
	_init_physics_state()
	# 2. 根据配置调整碰撞体大小（实现可配置的重叠距离）
	_update_collision_shape_size() 

## 初始化刚体的物理参数
## 作用：确保在动画播放期间，物体不会受物理引擎控制（不会乱滚、不会被撞飞）
func _init_physics_state():
	# 冻结模式：开启后，刚体位置完全由代码控制，忽略物理力
	freeze = true 
	
	# 关闭碰撞层级和掩码：防止在空中飞行时和玩家产生碰撞
	collision_layer = 0
	collision_mask = 0
	
	# 设置线性阻尼：落地解冻后，让物体受到推力后能迅速停下，而不是一直滑行
	linear_damp = 5.0 
	
	# 关闭重力：俯视角游戏通常不需要垂直重力
	gravity_scale = 0.0 
	
	# 锁定旋转：保证资源图片始终朝上，不会因为挤压而旋转
	lock_rotation = true
#endregion

#region 核心功能

## 执行抛物线爆出动画 (外部调用入口)
## [param start_pos]: 爆出起点 (通常是物件中心)
## [param target_pos]: 爆出落点 (计算出的随机位置)
func launch(start_pos: Vector2, target_pos: Vector2):
	# 强制设置初始位置
	global_position = start_pos
	
	# 获取 Sprite 节点用于做缩放和跳跃动画
	var sprite_node = get_node_or_null("Sprite2D")
	if not sprite_node: return

	# 记录图片原始的缩放值，防止动画结束后大小不对
	var original_scale = sprite_node.scale 

	# --- 创建动画序列 ---
	var tween = create_tween()
	var duration = randf_range(anim_duration_min, anim_duration_max)
	
	# 1. 水平位移：从起点移动到落点
	# 因为 freeze=true，Tween 可以直接修改 RigidBody 的 global_position 而不出错
	tween.tween_property(self, "global_position", target_pos, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. 并行播放 Sprite 的跳跃动画 (Y轴偏移)
	_animate_jump(sprite_node, duration)
	
	# 3. 并行播放 Sprite 的缩放动画 (Q弹效果)
	_animate_squash_stretch(sprite_node, duration, original_scale)

	# --- 等待动画结束 ---
	await tween.finished
	
	# --- 落地处理 ---
	# 恢复物理模拟，让资源之间开始互相挤压
	#_restore_physics_state()
#endregion

#region 内部辅助逻辑

## [内部] 处理 Sprite 的跳跃动画
## 作用：通过操作 Sprite 的 Y 轴偏移，模拟物体抛物线的高度视觉效果
func _animate_jump(sprite: Node2D, duration: float):
	var height_tween = create_tween()
	
	# 上升阶段：Y 轴向上 (负方向) 移动
	height_tween.tween_property(sprite, "position:y", -jump_height, duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# 下落阶段：Y 轴归零
	height_tween.chain().tween_property(sprite, "position:y", 0.0, duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## [内部] 处理 Sprite 的缩放动画 (Squash & Stretch)
## 作用：实现“出现 -> 变大 -> 压扁 -> 回弹”的果冻质感
func _animate_squash_stretch(sprite: Node2D, duration: float, base_scale: Vector2):
	# 设置初始大小 (由 start_scale_ratio 控制，比如 Vector2.ZERO 就是从无到有)
	sprite.scale = base_scale * start_scale_ratio
	
	var scale_tween = create_tween()
	
	# 1. 弹出变大 (Stretch)：超过原始大小一点点
	scale_tween.tween_property(sprite, "scale", base_scale * stretch_ratio, duration * 0.7)
	
	# 2. 落地压扁 (Squash)：变得比原始大小扁一点
	scale_tween.chain().tween_property(sprite, "scale", base_scale * squash_ratio, 0.1)
	
	# 3. 弹性恢复：回到原始大小
	scale_tween.chain().tween_property(sprite, "scale", base_scale, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## [内部] 落地后恢复物理状态
## 作用：动画播完后，将物体交还给物理引擎，开启碰撞，使其能被其他物体挤开
#func _restore_physics_state():
	## 恢复碰撞层级 (假设 Items 是第5层 = 16)
	#collision_layer = TARGET_LAYER_VALUE
	#collision_mask = TARGET_LAYER_VALUE 
	#
	## 解除冻结，物理引擎开始计算推力
	#freeze = false

## [内部] 根据配置动态调整碰撞体大小
## 作用：修改 CollisionShape2D 的半径，来实现“视觉重叠但物理不重叠”的效果
func _update_collision_shape_size():
	var collision_node = get_node_or_null("CollisionShape2D")
	if not collision_node:
		push_warning("PickupItem: 找不到 CollisionShape2D，无法调整间距。")
		return
		
	# 仅支持圆形碰撞体 (最适合处理均匀挤压)
	if collision_node.shape is CircleShape2D:
		# 必须使用 duplicate()！
		# 否则修改 shape 会影响到所有使用同一个 .tscn 的资源，导致所有资源半径都变了
		var new_shape = collision_node.shape.duplicate()
		
		# 计算半径：
		# 两个圆形相切时，圆心距离 = 半径A + 半径B。
		# 假设两个资源半径一样，那么 半径 = 期望的中心间距 / 2。
		new_shape.radius = min_center_distance / 2.0
		
		# 应用新的形状
		collision_node.shape = new_shape
	else:
		push_warning("PickupItem: 碰撞体形状不是 CircleShape2D，间距配置可能不准确。")
#endregion
