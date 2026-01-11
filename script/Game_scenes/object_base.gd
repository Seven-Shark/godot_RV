extends RigidBody2D
class_name ObjectBase

## 基础物件类 (ObjectBase)
##
## 负责处理场景中所有可交互物件的通用逻辑，包括：
## 1. 物理材质与属性配置
## 2. 受击反馈 (果冻特效、震荡波位移)
## 3. 引力枪交互 (连根拔起效果)
## 4. 掉落物生成与销毁

#region 1. 基础配置与枚举
# ... (枚举和导出变量保持不变，这里省略以节省篇幅，保持你原有的即可) ...
# 定义材质类型，用于 ERS 系统识别
enum ObjectMaterial {
	WOOD,   # 木头：低弹力，易碎
	STONE,  # 石头：无弹力，坚硬，重
	METAL,  # 金属：无弹力，极硬
	RUBBER, # 橡胶：高弹力，轻
	GHOST   # 灵体：可穿透
}

@export_group("Object Config")
@export var object_name: String = "Object" ## 物件名称
@export var material_type: ObjectMaterial = ObjectMaterial.WOOD ## 材质类型
@export var is_destructible: bool = true ## 是否可被破坏

@export_group("Physics Properties")
@export var is_movable_by_default: bool = false ## 初始状态：是否受物理引擎控制
@export var mass_override: float = 10.0         ## 质量覆盖

@export_group("Visual Effects")
@export var jelly_strength: Vector2 = Vector2(1.2, 0.8) ## 果冻特效强度
@export var jelly_duration: float = 1.0 ## 果冻特效持续时间

@export_group("Loot Settings")
@export var loot_table: Array[LootData] = [] ## 掉落表配置
@export var drop_radius: float = 60.0        ## 掉落散布半径
#endregion

#region 2. 组件引用
@onready var stats: StatsComponent = get_node_or_null("StatsComponent")
@onready var collider: CollisionShape2D = get_node_or_null("CollisionShape2D")
@export var sprite: Node2D ## 视觉精灵 (支持 Sprite2D 或 AnimatedSprite2D)
#endregion

#region 3. 内部状态变量
# --- 基础状态 ---
var default_scale: Vector2       ## 初始缩放
var default_pos: Vector2         ## 初始位置 (相对于父节点)
var original_sprite_pos: Vector2 ## Sprite 的原始局部坐标 (用于震动复位)
var current_tween: Tween         ## 通用动画控制器 (受击、恢复等)

# --- 引力枪系统变量 ---
var is_under_gravity: bool = false ## 当前是否正被引力枪吸住
var gravity_pull_tween: Tween      ## 专门控制“连根拔起”流程的 Tween
var is_shaking: bool = false       ## 是否进入“抖动”阶段
var shake_timer: float = 0.0       ## 抖动计时器
var is_dying: bool = false         ## 防止死亡逻辑多次触发
#endregion

#region 4. 初始化逻辑
func _ready() -> void:
	# [1] 初始化物理属性
	mass = mass_override
	_setup_physics_material()
	
	# [2] 设置初始移动状态
	call_deferred("set_mobility", is_movable_by_default)

	# [3] 连接生命值组件
	if stats:
		stats.died.connect(_on_object_destroyed)
		
	# [4] 记录视觉初始状态
	if sprite:
		default_scale = sprite.scale
		default_pos = sprite.position
		original_sprite_pos = sprite.position 
		print("[%s] 初始化完毕 | Scale: %s" % [object_name, default_scale])
#endregion

#region 5. 核心功能模块 (物理与通用)
## 配置物理材质
func _setup_physics_material():
	var phys_mat = PhysicsMaterial.new()
	match material_type:
		ObjectMaterial.RUBBER:
			phys_mat.bounce = 0.8; phys_mat.friction = 0.5
		ObjectMaterial.STONE:
			phys_mat.bounce = 0.0; phys_mat.friction = 1.0
		ObjectMaterial.WOOD:
			phys_mat.bounce = 0.2; phys_mat.friction = 0.8
		ObjectMaterial.METAL:
			phys_mat.bounce = 0.1; phys_mat.friction = 0.4
	physics_material_override = phys_mat

## 切换移动性
func set_mobility(active: bool):
	if active:
		freeze = false; sleeping = false
		if sprite: sprite.modulate = Color(1.2, 1.2, 1.2)
	else:
		freeze = true; linear_velocity = Vector2.ZERO; angular_velocity = 0
		if sprite: sprite.modulate = Color.WHITE

## 受伤处理
func take_damage(amount: int, _attacker_type: int, attacker_node: Node2D = null) -> void:
	if not is_destructible: return

	# 1. 寻找攻击来源
	var target_pos = Vector2.ZERO
	if attacker_node:
		target_pos = attacker_node.global_position
	else:
		var player = get_tree().get_first_node_in_group("Player")
		if player: target_pos = player.global_position

	# 2. 扣血 (死亡信号会自动触发 _on_object_destroyed)
	if stats:
		stats.take_damage(float(amount))

	# 3. 视觉反馈 (只有活着的时候才播放受伤动画)
	if target_pos != Vector2.ZERO and not is_dying:
		trigger_jelly_effect(target_pos)
#endregion

#region 6. 引力枪交互逻辑 (核心修改)

## [入口] 应用引力视觉效果 (每帧调用)
func apply_gravity_visual(attractor_pos: Vector2):
	if is_dying: return # 死了就别动了
	
	# 如果已经在流程中，只需要维持抖动计算
	if is_under_gravity:
		if is_shaking and sprite:
			_process_shake(attractor_pos)
		return

	# --- 首次触发：初始化状态 ---
	is_under_gravity = true
	is_shaking = false
	
	# 1. 物理稳定
	linear_velocity *= 0.1 
	angular_velocity *= 0.1
	
	# 2. 停止自身动画
	_stop_sprite_animation()

	# 3. 启动“连根拔起”的前摇动画（拔高 -> 悬停抖动）
	if gravity_pull_tween: gravity_pull_tween.kill()
	gravity_pull_tween = create_tween()
	
	# [阶段 1] 拔高 & 拉伸 (0.3秒)
	var lift_height = 20.0
	var lift_pos = original_sprite_pos + Vector2.UP * lift_height
	
	gravity_pull_tween.set_parallel(true)
	gravity_pull_tween.tween_property(sprite, "position", lift_pos, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	gravity_pull_tween.tween_property(sprite, "scale", default_scale * Vector2(0.8, 1.2), 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	gravity_pull_tween.tween_property(sprite, "modulate", Color(0.5, 1.5, 2.0, 1.0), 0.3)

	# [阶段 2] 进入抖动状态 (串行)
	gravity_pull_tween.chain().tween_callback(func(): is_shaking = true)
	
	# 【核心修改】删除了原本在这里的 "1.2秒后直接死亡" 的计时器
	# 现在它会一直保持悬停抖动状态，直到血量归零

## [内部] 处理引力状态下的中断/恢复
func recover_from_gravity():
	if not is_under_gravity or is_dying: return
		
	is_under_gravity = false
	is_shaking = false
	
	if gravity_pull_tween: gravity_pull_tween.kill()
	if current_tween: current_tween.kill()
	current_tween = create_tween()
	
	current_tween.set_parallel(true)
	# 回到原始位置
	current_tween.tween_property(sprite, "position", original_sprite_pos, 0.4)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# 恢复缩放
	current_tween.tween_property(sprite, "scale", default_scale, 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# 恢复颜色
	current_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	current_tween.tween_property(sprite, "rotation", 0.0, 0.4)
	
	if sprite is AnimatedSprite2D:
		sprite.play() 

## [内部] 处理每帧的抖动计算
func _process_shake(_attractor_pos: Vector2):
	shake_timer += get_process_delta_time() * 30.0 
	var shake_offset = Vector2(sin(shake_timer) * 3.0, 0)
	var lift_height = 20.0
	sprite.position = original_sprite_pos + Vector2.UP * lift_height + shake_offset

## [内部] 强制停止物件自身的帧动画
func _stop_sprite_animation():
	if sprite is AnimatedSprite2D:
		sprite.stop()
		sprite.frame = 0 
	# 尝试查找 AnimationPlayer
	var anim_player = get_node_or_null("AnimationPlayer")
	if anim_player:
		anim_player.stop()

## 【核心修改】仅播放飞天动画，不再负责触发死亡信号
func _play_gravity_death_anim():
	# 播放快速飞向天空消失的动画
	var final_tween = create_tween()
	final_tween.set_parallel(true)
	
	# 向上飞出 (速度快一点)
	final_tween.tween_property(sprite, "position", original_sprite_pos + Vector2.UP * 400, 0.15)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	# 缩放至无
	final_tween.tween_property(sprite, "scale", Vector2.ZERO, 0.15)
	
	# 等待动画播放完
	await final_tween.finished
#endregion

#region 7. 视觉特效 (受击与震荡)
# ... (保持原样，省略) ...
func trigger_jelly_effect(attacker_pos: Vector2):
	if not sprite: return
	if current_tween: current_tween.kill()
	sprite.rotation = 0 
	current_tween = create_tween()
	var dir_to_attacker = attacker_pos - sprite.global_position
	var target_angle = clamp(Vector2.UP.angle_to(dir_to_attacker), deg_to_rad(-35), deg_to_rad(35))
	var pull_scale = default_scale * Vector2(0.6, 1.4)
	current_tween.set_parallel(true)
	current_tween.tween_property(sprite, "rotation", target_angle, 0.15).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(sprite, "scale", pull_scale, 0.15).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(sprite, "modulate", Color(1.5, 0.7, 0.7), 0.15)
	current_tween.chain().tween_interval(0.05)
	current_tween.chain().set_parallel(true)
	current_tween.tween_property(sprite, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(sprite, "scale", default_scale, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func trigger_shockwave_shake(hit_dir: Vector2):
	if not sprite: return
	if current_tween: current_tween.kill()
	current_tween = create_tween()
	var target_offset = hit_dir.rotated(-global_rotation) * 20.0
	current_tween.tween_property(sprite, "position", default_pos + target_offset, 0.05).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	current_tween.parallel().tween_property(sprite, "modulate", Color(2, 2, 2), 0.05)
	current_tween.chain().tween_property(sprite, "position", default_pos, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	current_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.2)
#endregion

#region 8. 销毁与掉落

## 【核心修改】统一的死亡处理入口
# 无论是被打死还是被吸死，都会走到这里
func _on_object_destroyed():
	if is_dying: return # 防止重复调用
	is_dying = true
	
	print("[%s] 生命归零，准备销毁" % object_name)
	
	# 如果死亡时正被引力吸住，则播放“连根拔起飞天”的动画
	if is_under_gravity:
		await _play_gravity_death_anim()
	
	# 动画播完（或不需要播）后，生成掉落并删除
	_spawn_loot()
	queue_free()

## 生成掉落物
func _spawn_loot():
	if loot_table.is_empty(): return
	for loot_data in loot_table:
		var count = loot_data.get_drop_count()
		for i in range(count):
			_instantiate_item(loot_data.item_scene)

## 实例化掉落单体
func _instantiate_item(item_scene: PackedScene):
	if not item_scene: return
	var item = item_scene.instantiate()
	get_parent().call_deferred("add_child", item)
	var base_angle = 0.0 if randf() > 0.5 else PI
	var spread = deg_to_rad(45.0) 
	var random_angle = base_angle + randf_range(-spread, spread)
	var dist = randf_range(20.0, drop_radius)
	var random_offset = Vector2.RIGHT.rotated(random_angle) * dist
	var target_pos = global_position + random_offset
	if item.has_method("launch"):
		item.launch(global_position, target_pos)
#endregion
