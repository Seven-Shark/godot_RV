extends Node2D

#region 节点引用
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $Weapon_Hitbox
@onready var shockwave_vfx: ColorRect = $Weapon_Hitbox/ShockwaveVFX
@onready var gravity_viz: Polygon2D = $Weapon_Hitbox/GravityViz
@onready var muzzle: Marker2D = $Weapon_Hitbox/Muzzle ## [新增] 枪口位置，用于定位被吸附的物体
#endregion

#region 战斗参数配置
@export_group("Combat Stats")
@export var gravitation_damage_amount: int = 10      ## 引力波每跳伤害
@export var shock_damage_amount: int = 50            ## 震荡波单次伤害
@export var gravity_force: float = 400.0             ## 引力波吸附力度
@export var damage_interval: float = 0.5             ## 引力波伤害间隔时间
@export var shock_knockback_force: float = 1200.0    ## 震荡波击退力度
#endregion

#region 重物吸附配置
@export_group("Heavy Object Handling")
@export var throw_force: float = 1500.0              ## [新增] 重物发射/喷射的力度
@export var capture_distance: float = 30.0           ## [新增] 触发吸附的距离阈值
@export var heavy_object_tag: String = "Heavy"       ## [新增] 重物标签(Group名)，只有在此组内的RigidBody才能被吸起
#endregion

#region 视觉特效配置
@export_group("Visual Effects")
@export var shockwave_duration: float = 0.3          ## 震荡波扩散动画持续时间
@export var shockwave_angle: float = 90.0            ## 震荡波扇形角度(需匹配Hitbox)
#endregion

#region 连发与冷却配置
@export_group("Shockwave Settings")
@export var shock_fire_interval: float = 1.0         ## 震荡波自动连发间隔(秒)
var shock_cooldown_timer: float = 0.0                ## [内部] 震荡波冷却计时器
#endregion

#region 内部状态变量
var belonger: CharacterBase                          ## 武器持有者引用
var damage_timer: float = 0.0                        ## [内部] 伤害触发计时器
var captured_bodies: Array[Node2D] = []              ## [内部] 当前被引力捕获的物体列表
var held_object: RigidBody2D = null                  ## [新增] 当前正被吸住的重物引用
#endregion

#region 生命周期
func _ready() -> void:
	# 初始化判定框
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.monitoring = false
	hitbox.visible = false
	
	# 初始化特效状态
	if shockwave_vfx:
		shockwave_vfx.visible = false
		
	if gravity_viz:
		gravity_viz.visible = false
		gravity_viz.color = Color(0.0, 1.0, 1.0, 0.3)
		_update_gravity_viz_shape()

func _physics_process(delta: float) -> void:
	_update_cooldowns(delta)
	
	# 如果持有物体，每帧强制更新其位置到枪口
	if held_object:
		_process_holding_object(delta)
		
	_handle_input(delta)
#endregion

#region 核心循环逻辑
## 更新震荡波等技能的冷却计时器
func _update_cooldowns(delta: float) -> void:
	if shock_cooldown_timer > 0:
		shock_cooldown_timer -= delta

## 检测玩家输入并根据优先级分发行为（持有物体 > 震荡波 > 引力波）
func _handle_input(delta: float) -> void:
	var is_firing_shock = GameInputEvents.is_main_attack_held()    
	var is_firing_gravity = GameInputEvents.is_special_attack_held() 
	
	# --- 1. 持有重物状态下的输入处理 ---
	if held_object != null:
		# 左键点击 -> 发射重物
		if GameInputEvents.is_main_attack_just_pressed(): 
			_shoot_held_object()
			return 
			
		# 右键点击 -> 原地放下
		if GameInputEvents.is_special_attack_just_pressed() or is_firing_gravity:
			_drop_held_object()
			return
			
		# 维持吸附状态，不进行其他操作
		return 
	
	# --- 2. 普通状态下的输入处理 ---
	if is_firing_shock and not is_firing_gravity:
		_try_fire_shockwave()
	elif is_firing_gravity:
		_process_gravity_behavior(delta)
	else:
		_reset_weapon_state()
#endregion

#region 重物交互逻辑 (Heavy Object Logic)
## [新增] 每帧处理被吸住的物体的位置同步
func _process_holding_object(_delta: float) -> void:
	if not is_instance_valid(held_object):
		held_object = null
		return
		
	# 强制位置同步到枪口 Muzzle
	held_object.global_position = muzzle.global_position
	held_object.global_rotation = global_rotation # 让物体跟随枪口旋转

## [新增] 尝试捕获范围内的重物
## 返回: bool (是否成功捕获)
func _try_capture_heavy_object(body: Node2D) -> bool:
	# 必须是 RigidBody2D，且在 "Heavy" 组内
	if body is RigidBody2D and body.is_in_group(heavy_object_tag):
		var dist = global_position.distance_to(body.global_position)
		if dist <= capture_distance:
			_capture_object(body)
			return true 
	return false

## [新增] 执行捕获动作：冻结物理并停止引力波
func _capture_object(body: RigidBody2D) -> void:
	held_object = body
	held_object.freeze = true # 冻结物理，避免引擎冲突
	
	# 停止引力波逻辑 (枪口被堵住)
	stop_gravity_firing()
	print("Captured Heavy Object: ", body.name)

## [新增] 发射重物 (左键)
func _shoot_held_object() -> void:
	if not held_object: return
	
	var obj = held_object
	_release_object() # 先解绑
	
	# 计算发射方向 (基于枪的当前旋转)
	var shoot_dir = Vector2.RIGHT.rotated(global_rotation) 
	
	# 施加瞬时推力
	obj.apply_central_impulse(shoot_dir * throw_force)
	
	# 播放发射动作 (复用震荡波表现)
	play_attack() 
	trigger_shockwave_vfx() 

## [新增] 原地放下重物 (右键)
func _drop_held_object() -> void:
	if not held_object: return
	_release_object()

## [新增] 通用解绑逻辑：恢复物理并设置冷却
func _release_object() -> void:
	if not held_object: return
	
	held_object.freeze = false # 恢复物理模拟
	held_object = null
	
	# 增加短暂冷却，防止刚放下瞬间又被吸回来
	shock_cooldown_timer = 0.2
#endregion

#region 调试与参数调整 (HUD 接口)
## [HUD] 设置扇形攻击角度
func set_attack_angle(new_angle: float) -> void:
	shockwave_angle = new_angle
	if shockwave_vfx and shockwave_vfx.material:
		(shockwave_vfx.material as ShaderMaterial).set_shader_parameter("sector_angle_degrees", new_angle)
	_update_gravity_viz_shape()

## [HUD] 设置扇形半径 (碰撞体大小)
func set_attack_radius(new_radius: float) -> void:
	var collision = hitbox.get_node_or_null("CollisionShape2D")
	if collision and collision.shape is CircleShape2D:
		collision.shape.radius = new_radius
	
	if shockwave_vfx:
		var diameter = new_radius * 2.0
		shockwave_vfx.size = Vector2(diameter, diameter)
		shockwave_vfx.position = Vector2(-new_radius, -new_radius) 
		
	_update_gravity_viz_shape()

## [内部] 判断目标是否在扇形角度内
func _is_in_attack_angle(target_body: Node2D) -> bool:
	var direction_to_target = (target_body.global_position - global_position).normalized()
	# Hitbox 的 X 轴即为武器正前方
	var weapon_forward = hitbox.global_transform.x.normalized()
	var angle_diff = rad_to_deg(weapon_forward.angle_to(direction_to_target))
	return abs(angle_diff) <= (shockwave_angle / 2.0)
#endregion

#region 可视化辅助功能
## 更新引力范围的可视化多边形形状
func _update_gravity_viz_shape() -> void:
	if not gravity_viz: return
	
	var collision = hitbox.get_node_or_null("CollisionShape2D")
	if not collision or not (collision.shape is CircleShape2D):
		return
		
	var radius = collision.shape.radius
	var angle_rad = deg_to_rad(shockwave_angle)
	
	var points = PackedVector2Array()
	points.append(Vector2.ZERO)
	
	var segments = 32 
	var start_angle = -angle_rad / 2.0
	var angle_step = angle_rad / segments
	
	for i in range(segments + 1):
		var current_angle = start_angle + i * angle_step
		var point_on_arc = Vector2(cos(current_angle), sin(current_angle)) * radius
		points.append(point_on_arc)
		
	gravity_viz.polygon = points

## 触发可视化区域的瞬间闪烁 (左键攻击提示)
func _flash_attack_viz() -> void:
	if not gravity_viz: return
	gravity_viz.visible = true
	gravity_viz.modulate.a = 1.0
	
	var tween = create_tween()
	tween.tween_property(gravity_viz, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): 
		gravity_viz.visible = false
		gravity_viz.modulate.a = 1.0 
	)
#endregion

#region 震荡波行为 (Shockwave)
## 尝试触发震荡波攻击
func _try_fire_shockwave() -> void:
	if shock_cooldown_timer > 0: return
	if anim.current_animation == "Gravitataion_Attract": return 
	play_attack()
	shock_cooldown_timer = shock_fire_interval

## 执行攻击表现：播放动画和特效
func play_attack() -> void:
	anim.play("Gravitataion_Shock")
	trigger_shockwave_vfx()
	_flash_attack_viz()

## 震荡波碰撞判定回调
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body == belonger: return
	# 确保只在震荡波动画播放时生效
	if anim.current_animation != "Gravitataion_Shock": return
	
	if not _is_in_attack_angle(body): return
	
	if body.has_method("take_damage"):
		body.take_damage(shock_damage_amount, belonger.character_type, belonger)
		var knockback_dir = (body.global_position - belonger.global_position).normalized()
		
		# 对 ObjectBase 和 CharacterBase 分别处理击退
		if body is ObjectBase and body.has_method("trigger_shockwave_shake"):
			body.trigger_shockwave_shake(knockback_dir)
		elif body is CharacterBase and body.has_method("apply_knockback"):
			body.apply_knockback(knockback_dir, shock_knockback_force)
#endregion

#region 引力波行为 (Gravity)
## 引力波状态下的每帧逻辑入口
func _process_gravity_behavior(delta: float) -> void:
	if anim.current_animation != "Gravitataion_Attract":
		play_holdattack()
	process_gravity_tick(delta)

## 播放引力波持续动画
func play_holdattack() -> void:
	anim.play("Gravitataion_Attract")
	if gravity_viz: gravity_viz.visible = true

## [核心] 引力波物理计算：检测、吸附、伤害
func process_gravity_tick(delta: float) -> void:
	if not hitbox.monitoring:
		hitbox.visible = true
		hitbox.monitoring = true
	
	# 强制抖动 Hitbox 以持续刷新 overlapping_bodies (解决静止物体检测问题)
	hitbox.position.x = 0.001 if Engine.get_physics_frames() % 2 == 0 else -0.001
	
	damage_timer -= delta
	var can_deal_damage = damage_timer <= 0
	if can_deal_damage:
		damage_timer = damage_interval 
	
	var current_bodies = hitbox.get_overlapping_bodies()
	var current_targets: Array[Node2D] = []
	
	for body in current_bodies:
		if body == belonger: continue 
		if not _is_in_attack_angle(body): continue
		
		# 1. 优先检查重物吸附
		if _try_capture_heavy_object(body):
			return # 成功吸附后中断引力波

		# 2. 掉落物处理
		if body is PickupItem:
			body.start_absorbing(belonger)
			continue
		
		# 3. ObjectBase 和 CharacterBase 的引力与伤害处理
		if body is ObjectBase:
			current_targets.append(body)
			_apply_gravity_to_object(body, can_deal_damage)
				
		elif body is CharacterBase and body.has_method("take_damage"):
			if can_deal_damage:
				body.take_damage(gravitation_damage_amount, belonger.character_type, belonger)

	_handle_escaping_bodies(current_targets)
	captured_bodies = current_targets.duplicate()

## 对单个物体施加引力和伤害
func _apply_gravity_to_object(body: ObjectBase, can_damage: bool) -> void:
	var direction = (belonger.global_position - body.global_position).normalized()
	
	if body is RigidBody2D:
		body.apply_central_force(direction * gravity_force * body.mass * 2.0)
	
	body.apply_gravity_visual(belonger.global_position)
	
	if can_damage and body.stats:
		body.take_damage(gravitation_damage_amount, belonger.character_type, belonger)

## 恢复那些逃离引力范围的物体状态
func _handle_escaping_bodies(current_targets: Array[Node2D]) -> void:
	for old_body in captured_bodies:
		if not is_instance_valid(old_body): continue
		if old_body not in current_targets:
			if old_body.has_method("recover_from_gravity"):
				old_body.recover_from_gravity()

## 停止引力波：清理状态
func stop_gravity_firing() -> void:
	hitbox.visible = false
	hitbox.monitoring = false
	
	if gravity_viz: gravity_viz.visible = false
	
	if captured_bodies.size() > 0:
		for body in captured_bodies:
			if is_instance_valid(body) and body.has_method("recover_from_gravity"):
				body.recover_from_gravity()
		captured_bodies.clear()
#endregion

#region 通用状态管理
## 播放待机动画
func play_idle() -> void:
	if anim.current_animation != "Gravitataion_Shock":
		anim.play("Gravitation_Idle") 

## 重置武器状态 (松开按键或被打断时)
func _reset_weapon_state() -> void:
	if anim.current_animation == "Gravitataion_Attract":
		stop_gravity_firing()
		play_idle()
	elif anim.current_animation == "":
		play_idle()
		if hitbox.monitoring: stop_gravity_firing()
#endregion

#region 视觉特效逻辑
## 触发震荡波 Shader 特效
func trigger_shockwave_vfx() -> void:
	if not shockwave_vfx or not shockwave_vfx.material: return
	
	shockwave_vfx.visible = true
	var mat = shockwave_vfx.material as ShaderMaterial
	mat.set_shader_parameter("radius_progress", 0.0)
	mat.set_shader_parameter("sector_angle_degrees", shockwave_angle)
	
	var tween = create_tween()
	tween.tween_method(
		func(val): mat.set_shader_parameter("radius_progress", val), 
		0.0, 1.0, shockwave_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): shockwave_vfx.visible = false)
#endregion
