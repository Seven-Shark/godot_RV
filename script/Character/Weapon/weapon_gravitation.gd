extends Node2D

#region 节点引用
@onready var anim: AnimationPlayer = $AnimationPlayer ## 动画播放器节点
@onready var hitbox: Area2D = $Weapon_Hitbox ## 武器的攻击判定区域节点
@onready var shockwave_vfx: ColorRect = $Weapon_Hitbox/ShockwaveVFX ## 震荡波着色器视觉特效节点
@onready var gravity_viz: Polygon2D = $Weapon_Hitbox/GravityViz ## 引力波范围可视化多边形节点
@onready var muzzle: Marker2D = $RotationPos/Sprite2D/Muzzle ## 武器枪口位置节点
#endregion

#region 战斗参数配置
@export_group("Combat Stats")
@export var gravitation_damage_amount: int = 10 ## 引力波每跳造成的伤害值
@export var shock_damage_amount: int = 50 ## 震荡波单次造成的伤害值
@export var gravity_force: float = 400.0 ## 引力波拉扯物体的力度
@export var damage_interval: float = 0.5 ## 引力波造成持续伤害的时间间隔
@export var shock_knockback_force: float = 1200.0 ## 震荡波击退目标的力度
#endregion

#region 重物吸附配置
@export_group("Heavy Object Handling")
@export var throw_force: float = 2000.0 ## 重物发射时的初始力度
@export var capture_distance: float = 30.0 ## 判定重物被成功吸附到枪口的距离
@export var throw_damp: float = 2.0 ## 重物发射后的空气阻力（数值越大减速越快）
#endregion

#region 视觉特效配置
@export_group("Visual Effects")
@export var shockwave_duration: float = 0.3 ## 震荡波视觉特效的持续时间
@export var shockwave_angle: float = 90.0 ## 震荡波特效和判定的扇形角度
#endregion

#region 连发与冷却配置
@export_group("Shockwave Settings")
@export var shock_fire_interval: float = 1.0 ## 震荡波攻击的冷却时间间隔
var shock_cooldown_timer: float = 0.0 ## 记录震荡波当前剩余的冷却时间
#endregion

#region 内部状态变量
var belonger: CharacterBase ## 当前持有该武器的角色对象
var damage_timer: float = 0.0 ## 引力波伤害触发的计时器
var captured_bodies: Array[Node2D] = [] ## 当前被引力波捕获并正在受到影响的物体列表
var held_object: RigidBody2D = null ## 当前被武器吸附并处于待发射状态的重物节点
#endregion

#region 生命周期
## 初始化武器节点状态，隐藏特效并连接碰撞信号
func _ready() -> void:
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.monitoring = false
	hitbox.visible = false
	
	if shockwave_vfx: shockwave_vfx.visible = false
	if gravity_viz:
		gravity_viz.visible = false
		gravity_viz.color = Color(0.0, 1.0, 1.0, 0.3)
		_update_gravity_viz_shape()

## 物理帧更新入口，处理技能冷却、持物同步以及玩家输入指令
func _physics_process(delta: float) -> void:
	_update_cooldowns(delta)
	
	if held_object:
		_process_holding_object(delta)
		
	_handle_input(delta)
#endregion

#region 核心循环逻辑
## 更新武器各个技能的冷却计时器
func _update_cooldowns(delta: float) -> void:
	if shock_cooldown_timer > 0:
		shock_cooldown_timer -= delta

## 监听并处理玩家的攻击输入逻辑（发射重物、震荡波或引力波）
func _handle_input(delta: float) -> void:
	var is_firing_shock = GameInputEvents.is_main_attack_held()
	var is_firing_gravity = GameInputEvents.is_special_attack_held()
	
	if held_object != null:
		if hitbox.monitoring:
			stop_gravity_firing()
		
		if GameInputEvents.is_main_attack_just_pressed():
			_shoot_held_object()
		return
	
	if is_firing_shock and not is_firing_gravity:
		_try_fire_shockwave()
	elif is_firing_gravity:
		_process_gravity_behavior(delta)
	else:
		_reset_weapon_state()
#endregion

#region 重物交互逻辑
## 同步当前吸附在枪口位置的重物的空间变换
func _process_holding_object(_delta: float) -> void:
	if not is_instance_valid(held_object) or not held_object.is_inside_tree():
		held_object = null
		return
	
	held_object.global_position = muzzle.global_position
	held_object.global_rotation = global_rotation
	held_object.linear_velocity = Vector2.ZERO

## 判定并尝试将进入范围内的重物吸附为发射物
func _try_capture_heavy_object(body: Node2D) -> bool:
	if body is WorldEntity and body.entity_type == WorldEntity.EntityType.HEAVY:
		var dist = global_position.distance_to(body.global_position)
		if dist <= capture_distance:
			_capture_object(body)
			return true
	return false

## 执行重物吸附，关闭重物物理碰撞并将其绑定在武器上
func _capture_object(body: RigidBody2D) -> void:
	stop_gravity_firing()
	
	held_object = body
	held_object.freeze = true
	held_object.collision_layer = 0
	held_object.collision_mask = 0
	
	held_object.global_position = muzzle.global_position
	held_object.linear_velocity = Vector2.ZERO

## 将吸附的重物转化为物理投掷物并发射出去
func _shoot_held_object() -> void:
	if not held_object: return
	
	var obj = held_object
	
	play_attack()
	trigger_shockwave_vfx()
	
	held_object = null
	obj.freeze = false
	
	obj.collision_layer = WorldEntity.LAYER_PROP_MASK
	obj.collision_mask = 1 | 2
	
	var mouse_pos = get_global_mouse_position()
	var shoot_dir = (mouse_pos - muzzle.global_position).normalized()
	
	obj.apply_central_impulse(shoot_dir * throw_force)
	obj.global_rotation = shoot_dir.angle()
	obj.linear_damp = throw_damp
	
	if obj.has_method("recover_from_gravity"):
		obj.recover_from_gravity()
	
	shock_cooldown_timer = 0.5
#endregion

#region 调试与参数调整
## 动态修改武器的攻击扇形角度，并同步到着色器和辅助视觉图
func set_attack_angle(new_angle: float) -> void:
	shockwave_angle = new_angle
	if shockwave_vfx and shockwave_vfx.material:
		(shockwave_vfx.material as ShaderMaterial).set_shader_parameter("sector_angle_degrees", new_angle)
	_update_gravity_viz_shape()

## 动态修改武器的攻击半径大小，并同步到着色器和辅助视觉图
func set_attack_radius(new_radius: float) -> void:
	var collision = hitbox.get_node_or_null("CollisionShape2D")
	if collision and collision.shape is CircleShape2D:
		collision.shape.radius = new_radius
	if shockwave_vfx:
		var diameter = new_radius * 2.0
		shockwave_vfx.size = Vector2(diameter, diameter)
		shockwave_vfx.position = Vector2(-new_radius, -new_radius)
	_update_gravity_viz_shape()

## 检测指定目标物体当前是否处于武器的有效攻击扇形夹角内
func _is_in_attack_angle(target_body: Node2D) -> bool:
	var direction_to_target = (target_body.global_position - global_position).normalized()
	var weapon_forward = hitbox.global_transform.x.normalized()
	var angle_diff = rad_to_deg(weapon_forward.angle_to(direction_to_target))
	return abs(angle_diff) <= (shockwave_angle / 2.0)
#endregion

#region 可视化辅助功能
## 基于当前的攻击半径和角度，重新绘制引力波的多边形高亮区域
func _update_gravity_viz_shape() -> void:
	if not gravity_viz: return
	var collision = hitbox.get_node_or_null("CollisionShape2D")
	if not collision or not (collision.shape is CircleShape2D): return
	var radius = collision.shape.radius
	var angle_rad = deg_to_rad(shockwave_angle)
	var points = PackedVector2Array([Vector2.ZERO])
	var segments = 32
	var start_angle = -angle_rad / 2.0
	var angle_step = angle_rad / segments
	for i in range(segments + 1):
		var current_angle = start_angle + i * angle_step
		var point_on_arc = Vector2(cos(current_angle), sin(current_angle)) * radius
		points.append(point_on_arc)
	gravity_viz.polygon = points

## 播放攻击时扇形辅助区域的短暂高亮闪烁效果
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
## 检查技能冷却与动画状态，尝试执行震荡波攻击
func _try_fire_shockwave() -> void:
	if shock_cooldown_timer > 0: return
	if anim.current_animation == "Gravitataion_Attract": return
	play_attack()
	shock_cooldown_timer = shock_fire_interval

## 触发震荡波相关的动画、特效与视觉闪烁逻辑
func play_attack() -> void:
	anim.play("Gravitataion_Shock")
	trigger_shockwave_vfx()
	_flash_attack_viz()

## 震荡波判定区域进入物体时的回调，用于执行伤害与击退逻辑
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body == belonger: return
	if anim.current_animation != "Gravitataion_Shock": return
	if not _is_in_attack_angle(body): return
	
	if body.has_method("take_damage"):
		body.take_damage(shock_damage_amount, belonger.character_type, belonger)
		
		var knockback_dir = (body.global_position - belonger.global_position).normalized()
		if body is WorldEntity:
			pass
		elif body.has_method("apply_knockback"):
			body.apply_knockback(knockback_dir, shock_knockback_force)
#endregion

#region 引力波行为 (Gravity)
## 引力波状态主循环，负责动画衔接并调用逐帧引力逻辑
func _process_gravity_behavior(delta: float) -> void:
	if anim.current_animation != "Gravitataion_Attract":
		play_holdattack()
	process_gravity_tick(delta)

## 播放引力波持续施法时的动画和辅助特效
func play_holdattack() -> void:
	anim.play("Gravitataion_Attract")
	if gravity_viz: gravity_viz.visible = true

## 引力波逐帧核心逻辑：检测扇形范围内实体并施加物理拉拽与伤害
func process_gravity_tick(delta: float) -> void:
	if not hitbox.monitoring:
		hitbox.visible = true
		hitbox.monitoring = true
	
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
		
		if body is WorldEntity:
			if body.entity_type == WorldEntity.EntityType.HEAVY:
				if _try_capture_heavy_object(body):
					return
				_apply_gravity_to_entity(body, false)
				continue

			if body.entity_type == WorldEntity.EntityType.RESOURCE:
				body.start_absorbing(belonger)
				continue
			
			if body.entity_type == WorldEntity.EntityType.PROP:
				current_targets.append(body)
				_apply_gravity_to_entity(body, can_deal_damage)
			continue
			
		elif body is CharacterBase and body.has_method("take_damage"):
			if can_deal_damage:
				body.take_damage(gravitation_damage_amount, belonger.character_type, belonger)

	_handle_escaping_bodies(current_targets)
	captured_bodies = current_targets.duplicate()

## 对环境实体施加向心的物理引力和持续伤害
func _apply_gravity_to_entity(body: WorldEntity, can_damage: bool) -> void:
	var direction = (belonger.global_position - body.global_position).normalized()
	body.apply_central_force(direction * gravity_force * body.mass * 2.0)
	body.apply_gravity_visual(belonger.global_position)
	if can_damage:
		body.take_damage(gravitation_damage_amount, belonger.character_type, belonger)

## 检查并恢复那些已经脱离引力波攻击范围的物体的物理状态
func _handle_escaping_bodies(current_targets: Array[Node2D]) -> void:
	for old_body in captured_bodies:
		if not is_instance_valid(old_body): continue
		if old_body not in current_targets:
			if old_body.has_method("recover_from_gravity"):
				old_body.recover_from_gravity()

## 中止引力波行为，关闭判定区域并释放所有捕获物
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
## 控制武器播放默认的待机动画
func play_idle() -> void:
	if anim.current_animation != "Gravitataion_Shock":
		anim.play("Gravitation_Idle")

## 重置武器的所有活跃攻击状态回落至待机状态
func _reset_weapon_state() -> void:
	if anim.current_animation == "Gravitataion_Attract":
		stop_gravity_firing()
		play_idle()
	elif anim.current_animation == "":
		play_idle()
		if hitbox.monitoring: stop_gravity_firing()
#endregion

#region 视觉特效逻辑
## 控制震荡波扩散着色器参数的动画过渡
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
