extends RigidBody2D
class_name ObjectBase

# ==============================================================================
# 1. 基础配置与枚举
# ==============================================================================

# 定义材质类型，用于 ERS 系统识别
enum ObjectMaterial {
	WOOD,   # 木头：低弹力，易碎
	STONE,  # 石头：无弹力，坚硬，重
	METAL,  # 金属：无弹力，极硬
	RUBBER, # 橡胶：高弹力，轻
	GHOST   # 灵体：可穿透
}

# --- 导出变量：基础配置 ---
@export_group("Object Config")
@export var object_name: String = "Object"
@export var material_type: ObjectMaterial = ObjectMaterial.WOOD
@export var is_destructible: bool = true

# --- 导出变量：物理属性 ---
@export_group("Physics Properties")
@export var is_movable_by_default: bool = false # 初始状态：是否受物理引擎控制
@export var mass_override: float = 10.0         # 质量覆盖

# --- 引用组件 ---
@onready var stats: StatsComponent = get_node_or_null("StatsComponent")
@export var sprite: Node2D
@onready var collider: CollisionShape2D = get_node_or_null("CollisionShape2D")

# --- 导出变量：视觉特效参数 ---
@export_group("Visual Effects")
@export var jelly_strength: Vector2 = Vector2(1.2, 0.8)
@export var jelly_duration: float = 1.0

# ==============================================================================
# 2. 内部状态变量
# ==============================================================================

# 记录 Sprite 的初始状态
var default_scale: Vector2
var default_pos: Vector2

# 动画控制器
var current_tween: Tween

# 状态标记：当前是否正被引力枪吸住
var is_under_gravity: bool = false

# ==============================================================================
# 3. 初始化逻辑 (_ready)
# ==============================================================================
func _ready() -> void:
	# [步骤 1] 初始化物理质量
	mass = mass_override
	
	# [步骤 2] 设置物理材质
	_setup_physics_material()
	
	# [步骤 3] 设置初始移动状态
	call_deferred("set_mobility", is_movable_by_default)

	# [步骤 4] 连接生命值组件的死亡信号
	if stats:
		stats.died.connect(_on_object_destroyed)
		
	# [步骤 5] 记录视觉组件的初始状态
	if sprite:
		default_scale = sprite.scale
		default_pos = sprite.position
		print("树木初始化成功 | 初始 Scale: ", default_scale, " | 初始 Rotation: ", sprite.rotation)

# ==============================================================================
# 4. 核心功能模块
# ==============================================================================

# --- 功能 1：配置物理材质 ---
func _setup_physics_material():
	var phys_mat = PhysicsMaterial.new()
	
	match material_type:
		ObjectMaterial.RUBBER:
			phys_mat.bounce = 0.8
			phys_mat.friction = 0.5
		ObjectMaterial.STONE:
			phys_mat.bounce = 0.0
			phys_mat.friction = 1.0
		ObjectMaterial.WOOD:
			phys_mat.bounce = 0.2
			phys_mat.friction = 0.8
		ObjectMaterial.METAL:
			phys_mat.bounce = 0.1
			phys_mat.friction = 0.4
	
	# 将材质应用到 RigidBody2D
	physics_material_override = phys_mat

# --- 功能 2：切换移动性 (冻结/解冻) ---
func set_mobility(active: bool):
	if active:
		freeze = false
		sleeping = false
		if sprite: sprite.modulate = Color(1.2, 1.2, 1.2)
	else:
		freeze = true
		linear_velocity = Vector2.ZERO
		angular_velocity = 0
		if sprite: sprite.modulate = Color.WHITE

# --- 功能 3：受伤处理 (通用接口) ---
func take_damage(amount: int, attacker_type: int, attacker_node: Node2D = null) -> void:
	print(">>> [ObjectBase] 受到攻击！开始处理...")
	
	if not is_destructible:
		print(">>> 失败：物体不可破坏")
		return

	# [逻辑 A] 寻找攻击来源
	var target_pos = Vector2.ZERO
	if attacker_node:
		target_pos = attacker_node.global_position
	else:
		var player = get_tree().get_first_node_in_group("Player")
		if player:
			target_pos = player.global_position

	# [逻辑 B] 物理击退
	if not freeze and not sleeping:
		if attacker_node:
			print(">>> 路径A：获取到攻击者节点: ", attacker_node.name)
			var knockback_dir = (global_position - attacker_node.global_position).normalized()
			apply_central_impulse(knockback_dir * 100.0)
		else:
			print(">>> 警告：没有传入攻击者节点，尝试寻找 'Player' 组...")
			if target_pos != Vector2.ZERO:
				print(">>> 路径B：成功在组里找到 Player！")
			else:
				print(">>> ❌ 严重错误：没传攻击者，且场景里找不到属于 'Player' 组的节点！")

	# [逻辑 C] 扣除血量
	if stats:
		stats.take_damage(float(amount))

	# [逻辑 D] 触发视觉反馈
	if target_pos != Vector2.ZERO:
		print(">>> 成功：触发果冻特效！目标坐标: ", target_pos)
		trigger_jelly_effect(target_pos)
	else:
		print(">>> ❌ 失败：目标坐标无效 (Vector2.ZERO)，动画被跳过。")

# (旧版简单的闪烁效果)
func _play_hit_effect():
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.05)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.05)

# ==============================================================================
# 5. 引力枪交互逻辑 (新增)
# ==============================================================================

# --- 引力状态：持续形变 ---
func apply_gravity_visual(attractor_pos: Vector2):
	# 1. 标记状态
	is_under_gravity = true
	
	# 2. 杀掉之前的 Tween 动画
	if current_tween:
		current_tween.kill()
		
	## 3. 计算朝向
	#var direction = attractor_pos - global_position
	#var target_angle = Vector2.UP.angle_to(direction)
	#
	## 限制角度幅度
	#rotation = clamp(angle_difference(0, target_angle), deg_to_rad(-45), deg_to_rad(45))
	
	# 4. 持续拉伸
	sprite.scale = default_scale * Vector2(0.7, 1.4) 
	sprite.modulate = Color(1.832, 0.0, 0.289, 0.839)

# --- 引力状态：结束恢复 ---
func recover_from_gravity():
	if not is_under_gravity: 
		return
		
	is_under_gravity = false
	
	# 创建回弹动画
	if current_tween: current_tween.kill()
	current_tween = create_tween()
	
	current_tween.set_parallel(true)
	current_tween.tween_property(sprite, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(sprite, "scale", default_scale, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

# --- 果冻/拔萝卜特效 ---
func trigger_jelly_effect(attacker_pos: Vector2):
	if not sprite: return
	
	# 1. 准备工作
	if current_tween: current_tween.kill()
	sprite.rotation = 0 
	current_tween = create_tween()
	
	# --- [步骤 A] 计算“拔”的方向 ---
	var direction_to_attacker = attacker_pos - sprite.global_position
	var target_angle = Vector2.UP.angle_to(direction_to_attacker)
	
	var max_bend = deg_to_rad(35.0) 
	target_angle = clamp(target_angle, -max_bend, max_bend)

	# --- [步骤 B] 设定“拔”的形变目标 ---
	var pull_scale_target = default_scale * Vector2(0.6, 1.4)
	
	# --- [步骤 C] 设定动画节奏 ---
	var pull_duration = 0.15 
	var snap_duration = 0.4 

	# 开始定义 Tween 流程
	current_tween.set_parallel(true)
	
	# --- 阶段 1：受力被拔出 ---
	current_tween.tween_property(sprite, "rotation", target_angle, pull_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# ... (接上一段断开的地方: current_tween.tween_property(sprite, "scale", pull_scale_target, pull_) ...
	
	current_tween.tween_property(sprite, "scale", pull_scale_target, pull_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# 变红反馈：表现受力充能
	current_tween.tween_property(sprite, "modulate", Color(1.5, 0.7, 0.7), pull_duration)

	# --- 阶段 2：顶点停顿 (Hit Stop) ---
	# 串行执行 (Chain)：等待上面动画做完
	# 极短的停顿 (0.05秒)，让视觉上能看清“拉伸到了极限”，增强力度感
	current_tween.chain().tween_interval(0.05)
	
	# --- 阶段 3：松手回弹 (Snap Back) ---
	# 再次并行执行
	current_tween.chain().set_parallel(true)
	# 使用 ELASTIC：像弹簧一样晃动着归位
	current_tween.tween_property(sprite, "rotation", 0.0, snap_duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(sprite, "scale", default_scale, snap_duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# 颜色变回原色
	current_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
# --- 震荡波反馈 (视觉震动回弹) ---
func trigger_shockwave_shake(hit_dir: Vector2):
	if not sprite: return
	
	# 如果正在做果冻动画，先打断它，避免冲突
	if current_tween: current_tween.kill()
	current_tween = create_tween()
	
	# 震动参数
	var shake_distance = 20.0 # 向后震退的距离
	var shake_duration = 0.05 # 单次震动时间
	var return_duration = 0.2 # 回弹归位时间
	
	# 计算目标偏移量 (向受击方向移动)
	# 注意：我们移动的是 sprite 的 position，它是相对于 RigidBody 的局部坐标
	# 局部坐标原点通常是 (0,0)
	var target_offset = hit_dir.rotated(-global_rotation) * shake_distance # 需考虑物体自身的旋转
	
	# 1. 瞬间被“推”出去 (Sprite 位移)
	current_tween.tween_property(sprite, "position", default_pos + target_offset, shake_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	
	# 2. 稍微变色反馈
	current_tween.parallel().tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0), shake_duration) # 高亮闪白
	
	# 3. 弹回原位
	current_tween.chain().tween_property(sprite, "position", default_pos, return_duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	current_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, return_duration)
# --- 物体死亡处理 ---
func _on_object_destroyed():
	print(object_name + " 被摧毁")
	# 生成碎片特效、播放音效等逻辑可在此处添加
	queue_free() # 将物体从场景中移除
