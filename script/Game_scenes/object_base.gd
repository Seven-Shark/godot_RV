extends RigidBody2D
class_name ObjectBase

# 定义材质类型，用于 ERS 系统识别
enum ObjectMaterial {
	WOOD,   # 木头：低弹力，易碎
	STONE,  # 石头：无弹力，坚硬，重
	METAL,  # 金属：无弹力，极硬
	RUBBER, # 橡胶：高弹力，轻 (比如废旧轮胎)
	GHOST   # 灵体：可穿透 (ERS 特殊状态)
}

@export_group("Object Config")
@export var object_name: String = "Object"
@export var material_type: ObjectMaterial = ObjectMaterial.WOOD
@export var is_destructible: bool = true

@export_group("Physics Properties")
@export var is_movable_by_default: bool = false # 是否一出生就能推得动？
@export var mass_override: float = 10.0         # 质量（越重越难推）

# 引用组件
@onready var stats: StatsComponent = get_node_or_null("StatsComponent")
@export var sprite: Node2D
@onready var collider: CollisionShape2D = get_node_or_null("CollisionShape2D")

@export_group("Visual Effects")
@export var jelly_strength: Vector2 = Vector2(1.2, 0.8) # 拉伸强度：X变宽/变窄，Y变矮/变高
@export var jelly_duration: float = 1 # 回弹持续时间

# 记录 Sprite 的原始位置和缩放，防止多次叠加导致变形
var default_scale: Vector2
var default_pos: Vector2

# 用于存储当前的 Tween，方便打断
var current_tween: Tween

# 标记当前是否正在被引力枪控制
var is_under_gravity: bool = false

func _ready() -> void:
	# 1. 初始化物理属性
	mass = mass_override
	
	# 2. 设置物理材质
	_setup_physics_material()
	
	# 3. 设置初始移动状态
	# 注意：RigidBody2D 必须先添加到场景树才能正确应用某些物理状态，用 call_deferred 更稳妥
	call_deferred("set_mobility", is_movable_by_default)

	# 4. 连接死亡信号
	if stats:
		stats.died.connect(_on_object_destroyed)
		
	if sprite:
		default_scale = sprite.scale
		default_pos = sprite.position
		# 【调试打印】看看初始值对不对
		print("树木初始化成功 | 初始 Scale: ", default_scale, " | 初始 Rotation: ", sprite.rotation)

# --- 核心功能 1：配置物理材质 (弹力/摩擦力) ---
func _setup_physics_material():
	# 创建一个新的物理材质资源
	var phys_mat = PhysicsMaterial.new()
	
	match material_type:
		ObjectMaterial.RUBBER:
			phys_mat.bounce = 0.8  # 高弹力 (0-1)
			phys_mat.friction = 0.5
		ObjectMaterial.STONE:
			phys_mat.bounce = 0.0  # 无弹力
			phys_mat.friction = 1.0 # 高摩擦，很难推
		ObjectMaterial.WOOD:
			phys_mat.bounce = 0.2
			phys_mat.friction = 0.8
		ObjectMaterial.METAL:
			phys_mat.bounce = 0.1
			phys_mat.friction = 0.4
	
	# 应用材质
	physics_material_override = phys_mat

# --- 核心功能 2：ERS 状态切换 (冻结 vs 解冻) ---
# active = true: 变成可移动的物理实体
# active = false: 变成不可移动的障碍物
func set_mobility(active: bool):
	if active:
		freeze = false
		sleeping = false # 唤醒物理引擎
		# 可以在这里变颜色提示玩家“这东西现在能动了”
		if sprite: sprite.modulate = Color(1.2, 1.2, 1.2) # 稍微变亮
	else:
		freeze = true
		linear_velocity = Vector2.ZERO # 归零速度，防止解冻瞬间飞出去
		angular_velocity = 0
		if sprite: sprite.modulate = Color.WHITE

# --- 核心功能 3：受伤 (通用接口) ---
func take_damage(amount: int, attacker_type: int, attacker_node: Node2D = null) -> void:
	print(">>> [ObjectBase] 受到攻击！开始处理...")
	
	
	if not is_destructible:
		print(">>> 失败：物体不可破坏")
		return
	# 3. 触发果冻效果 (修正版)
	# 优先使用传入的攻击者节点，如果没有，再尝试去全局找玩家
	var target_pos = Vector2.ZERO
	
	
	# 1. 物理击退 (仅在非冻结状态下生效)
	if not freeze and not sleeping:
		# 如果能获取到攻击者，就向反方向击退；否则随机震动
		if attacker_node:
			print(">>> 路径A：获取到攻击者节点: ", attacker_node.name)
			var knockback_dir = (global_position - attacker_node.global_position).normalized()
			apply_central_impulse(knockback_dir * 100.0) # 这里的力度可以做成变量
		else:
			print(">>> 警告：没有传入攻击者节点，尝试寻找 'Player' 组...")
			var player = get_tree().get_first_node_in_group("Player")
			if player:
				print(">>> 路径B：成功在组里找到 Player！")
				target_pos = player.global_position
			else:
				print(">>> ❌ 严重错误：没传攻击者，且场景里找不到属于 'Player' 组的节点！")

	# 2. 扣血
	if stats:
		stats.take_damage(float(amount))

	if attacker_node:
		target_pos = attacker_node.global_position
	else:
		# 只有在没传攻击者时，才尝试找玩家作为备选
		var player = get_tree().get_first_node_in_group("Player")
		if player:
			target_pos = player.global_position
			
	# 如果确定了吸引源的位置，才触发效果
	if target_pos != Vector2.ZERO:
		print(">>> 成功：触发果冻特效！目标坐标: ", target_pos)
		trigger_jelly_effect(target_pos)
	else:
		print(">>> ❌ 失败：目标坐标无效 (Vector2.ZERO)，动画被跳过。")
func _play_hit_effect():
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.05)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.05)

# 持续受到引力影响（每一帧都会被武器调用）
func apply_gravity_visual(attractor_pos: Vector2):
	# 1. 标记状态
	is_under_gravity = true
	
	# 2. 杀掉之前的回弹动画，确保完全由物理和代码接管
	if current_tween:
		current_tween.kill()
		
	# 3. 计算朝向：让树顶 (Vector2.UP) 指向玩家
	var direction = attractor_pos - global_position
	var target_angle = Vector2.UP.angle_to(direction)
	# 限制角度，防止360度乱转，限制在 +/- 45度内
	rotation = clamp(angle_difference(0, target_angle), deg_to_rad(-45), deg_to_rad(45))
	
	# 4. 持续拉伸：变得细长 (模拟被吸住的张力)
	# 这里直接修改属性，不使用 Tween，因为位置每帧都在变
	sprite.scale = default_scale * Vector2(0.7, 1.4) 
	sprite.modulate = Color(0.8, 0.8, 2.0) # 变蓝一点，提示受到引力

# 引力波断开（松开鼠标 或 离开范围）
func recover_from_gravity():
	if not is_under_gravity: 
		return
		
	is_under_gravity = false
	
	# 播放回弹动画 (Snap Back)
	if current_tween: current_tween.kill()
	current_tween = create_tween()
	
	current_tween.set_parallel(true)
	# 快速回弹
	current_tween.tween_property(sprite, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(sprite, "scale", default_scale, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

# --- 新增：果冻效果逻辑 ---
# attacker_pos: 攻击者的位置，用于计算吸引方向
func trigger_jelly_effect(attacker_pos: Vector2):
	if not sprite: return
	
	# 1. 准备工作
	if current_tween: current_tween.kill()
	# 确保初始旋转归零，防止累积误差
	sprite.rotation = 0 
	current_tween = create_tween()
	
	# ==========================================
	# [步骤A] 计算“拔”的方向
	# ==========================================
	var direction_to_attacker = attacker_pos - sprite.global_position
	# 计算让树顶 (Vector2.UP) 指向攻击者需要的角度
	var target_angle = Vector2.UP.angle_to(direction_to_attacker)
	
	# 【限制角度】拔萝卜通常不会把萝卜横着拔出来，所以限制最大弯曲角度
	# 建议 30度 到 45度 之间，太大了看起来像树折断了
	var max_bend = deg_to_rad(35.0) 
	target_angle = clamp(target_angle, -max_bend, max_bend)

	# ==========================================
	# [步骤B] 设定“拔”的形变
	# ==========================================
	# X轴变细 (0.6)，Y轴变很长 (1.4) -> 模拟被拉伸变细的感觉
	# 结合上面的旋转，树就会顺着攻击者的方向被“拉长”
	var pull_scale_target = default_scale * Vector2(0.6, 1.4)
	
	# ==========================================
	# [步骤C] 设定“拔”的节奏 (关键)
	# ==========================================
	var pull_duration = 0.15  # 积蓄张力的过程 (稍快一点，更有打击感)
	var snap_duration = 0.4   # 回弹晃动的时间 (弹性十足)
	
	current_tween.set_parallel(true)
	
	# --- 阶段 1：受力被拔出 (拉伸 + 弯曲) ---
	# 使用 QUART + EASE_OUT 模拟阻力感（一开始快，后面拉不动）
	current_tween.tween_property(sprite, "rotation", target_angle, pull_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(sprite, "scale", pull_scale_target, pull_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# 变红反馈
	current_tween.tween_property(sprite, "modulate", Color(1.5, 0.7, 0.7), pull_duration)

	# --- 阶段 2：顶点停顿 (张力最大时刻) ---
	current_tween.chain().tween_interval(0.05)
	
	# --- 阶段 3：松手回弹 (Q弹复原) ---
	current_tween.chain().set_parallel(true)
	# 使用 ELASTIC 模拟像弹簧一样弹回去
	current_tween.tween_property(sprite, "rotation", 0.0, snap_duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(sprite, "scale", default_scale, snap_duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# 颜色变回
	current_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	

func _on_object_destroyed():
	print(object_name + " 被摧毁")
	# 生成碎片、播放音效
	queue_free()
