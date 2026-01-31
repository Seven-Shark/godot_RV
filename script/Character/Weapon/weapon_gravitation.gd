extends Node2D

#region 节点引用
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $Weapon_Hitbox
@onready var shockwave_vfx: ColorRect = $Weapon_Hitbox/ShockwaveVFX
@onready var gravity_viz: Polygon2D = $Weapon_Hitbox/GravityViz
@onready var muzzle: Marker2D = $Weapon_Hitbox/Muzzle ## 枪口位置
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
@export var throw_force: float = 1500.0              ## 重物发射力度
@export var capture_distance: float = 30.0           ## 吸附判定距离
#endregion

#region 视觉特效配置
@export_group("Visual Effects")
@export var shockwave_duration: float = 0.3          
@export var shockwave_angle: float = 90.0            
#endregion

#region 连发与冷却配置
@export_group("Shockwave Settings")
@export var shock_fire_interval: float = 1.0         
var shock_cooldown_timer: float = 0.0                
#endregion

#region 内部状态变量
var belonger: CharacterBase                          
var damage_timer: float = 0.0                        
var captured_bodies: Array[Node2D] = []              
var held_object: RigidBody2D = null                  ## 当前吸住的重物
#endregion

#region 生命周期
func _ready() -> void:
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.monitoring = false
	hitbox.visible = false
	
	if shockwave_vfx: shockwave_vfx.visible = false
	if gravity_viz:
		gravity_viz.visible = false
		gravity_viz.color = Color(0.0, 1.0, 1.0, 0.3)
		_update_gravity_viz_shape()

func _physics_process(delta: float) -> void:
	_update_cooldowns(delta)
	
	# 如果持有重物，每帧强制同步位置
	if held_object:
		_process_holding_object(delta)
		
	_handle_input(delta)
#endregion

#region 核心循环逻辑
func _update_cooldowns(delta: float) -> void:
	if shock_cooldown_timer > 0:
		shock_cooldown_timer -= delta

func _handle_input(delta: float) -> void:
	var is_firing_shock = GameInputEvents.is_main_attack_held()    
	var is_firing_gravity = GameInputEvents.is_special_attack_held() 
	
	# --- 1. 持有重物模式 ---
	if held_object != null:
		if GameInputEvents.is_main_attack_just_pressed(): 
			_shoot_held_object()
			return 
		if GameInputEvents.is_special_attack_just_pressed() or is_firing_gravity:
			_drop_held_object()
			return
		return # 维持吸附，不执行其他操作
	
	# --- 2. 普通模式 ---
	if is_firing_shock and not is_firing_gravity:
		_try_fire_shockwave()
	elif is_firing_gravity:
		_process_gravity_behavior(delta)
	else:
		_reset_weapon_state()
#endregion

#region 重物交互逻辑
func _process_holding_object(_delta: float) -> void:
	# [修复] 增加 is_inside_tree 检查，防止报错
	if not is_instance_valid(held_object) or not held_object.is_inside_tree():
		held_object = null
		return
		
	held_object.global_position = muzzle.global_position
	held_object.global_rotation = global_rotation

func _try_capture_heavy_object(body: Node2D) -> bool:
	# [适配] 检查是否为 WorldEntity 且类型为 HEAVY
	if body is WorldEntity and body.entity_type == WorldEntity.EntityType.HEAVY:
		var dist = global_position.distance_to(body.global_position)
		if dist <= capture_distance:
			_capture_object(body)
			return true 
	return false

func _capture_object(body: RigidBody2D) -> void:
	held_object = body
	held_object.freeze = true 
	stop_gravity_firing()
	# print("捕获重物: ", body.name)

func _shoot_held_object() -> void:
	if not held_object: return
	var obj = held_object
	_release_object() 
	var shoot_dir = Vector2.RIGHT.rotated(global_rotation) 
	obj.apply_central_impulse(shoot_dir * throw_force)
	play_attack() 
	trigger_shockwave_vfx() 

func _drop_held_object() -> void:
	if not held_object: return
	_release_object()

func _release_object() -> void:
	if not held_object: return
	
	# 调用 WorldEntity 的恢复接口
	if held_object.has_method("recover_from_gravity"):
		held_object.recover_from_gravity()
	else:
		held_object.freeze = false # 保底逻辑
		
	held_object = null
	shock_cooldown_timer = 0.2
#endregion

#region 调试与参数调整 (HUD 接口)
func set_attack_angle(new_angle: float) -> void:
	shockwave_angle = new_angle
	if shockwave_vfx and shockwave_vfx.material:
		(shockwave_vfx.material as ShaderMaterial).set_shader_parameter("sector_angle_degrees", new_angle)
	_update_gravity_viz_shape()

func set_attack_radius(new_radius: float) -> void:
	var collision = hitbox.get_node_or_null("CollisionShape2D")
	if collision and collision.shape is CircleShape2D:
		collision.shape.radius = new_radius
	if shockwave_vfx:
		var diameter = new_radius * 2.0
		shockwave_vfx.size = Vector2(diameter, diameter)
		shockwave_vfx.position = Vector2(-new_radius, -new_radius) 
	_update_gravity_viz_shape()

func _is_in_attack_angle(target_body: Node2D) -> bool:
	var direction_to_target = (target_body.global_position - global_position).normalized()
	var weapon_forward = hitbox.global_transform.x.normalized()
	var angle_diff = rad_to_deg(weapon_forward.angle_to(direction_to_target))
	return abs(angle_diff) <= (shockwave_angle / 2.0)
#endregion

#region 可视化辅助功能
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
func _try_fire_shockwave() -> void:
	if shock_cooldown_timer > 0: return
	if anim.current_animation == "Gravitataion_Attract": return 
	play_attack()
	shock_cooldown_timer = shock_fire_interval

func play_attack() -> void:
	anim.play("Gravitataion_Shock")
	trigger_shockwave_vfx()
	_flash_attack_viz()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body == belonger: return
	if anim.current_animation != "Gravitataion_Shock": return
	if not _is_in_attack_angle(body): return
	
	if body.has_method("take_damage"):
		# [修复] 确保调用的是 3 参数接口
		body.take_damage(shock_damage_amount, belonger.character_type, belonger)
		
		var knockback_dir = (body.global_position - belonger.global_position).normalized()
		# 兼容 WorldEntity
		if body is WorldEntity:
			# WorldEntity 的震动反馈在 take_damage 内部触发
			pass 
		elif body.has_method("apply_knockback"):
			body.apply_knockback(knockback_dir, shock_knockback_force)
#endregion

#region 引力波行为 (Gravity)
func _process_gravity_behavior(delta: float) -> void:
	if anim.current_animation != "Gravitataion_Attract":
		play_holdattack()
	process_gravity_tick(delta)

func play_holdattack() -> void:
	anim.play("Gravitataion_Attract")
	if gravity_viz: gravity_viz.visible = true

func process_gravity_tick(delta: float) -> void:
	if not hitbox.monitoring:
		hitbox.visible = true
		hitbox.monitoring = true
	
	# 强制抖动 Hitbox 刷新检测
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
		
		# --- [新架构适配] 统一处理 WorldEntity ---
		if body is WorldEntity:
			# 1. 优先尝试捕获重物 (HEAVY)
			# 如果是 HEAVY 类型，_try_capture 会返回 true 并中断后续逻辑
			if body.entity_type == WorldEntity.EntityType.HEAVY:
				if _try_capture_heavy_object(body): return 

			# 2. 处理资源吸附 (RESOURCE)
			if body.entity_type == WorldEntity.EntityType.RESOURCE:
				body.start_absorbing(belonger)
				continue
			
			# 3. 处理物件 (PROP)
			if body.entity_type == WorldEntity.EntityType.PROP:
				current_targets.append(body)
				_apply_gravity_to_entity(body, can_deal_damage)
			continue
			
		# --- [旧逻辑兼容] 处理敌人 (CharacterBase) ---
		elif body is CharacterBase and body.has_method("take_damage"):
			if can_deal_damage:
				body.take_damage(gravitation_damage_amount, belonger.character_type, belonger)

	_handle_escaping_bodies(current_targets)
	captured_bodies = current_targets.duplicate()

func _apply_gravity_to_entity(body: WorldEntity, can_damage: bool) -> void:
	# 1. 物理引力
	var direction = (belonger.global_position - body.global_position).normalized()
	body.apply_central_force(direction * gravity_force * body.mass * 2.0)
	
	# 2. [关键修复] 调用视觉接口，触发 VisualController 的悬停拉伸动画
	body.apply_gravity_visual(belonger.global_position)
	
	# 3. 造成伤害
	if can_damage:
		# [修复] 确保调用的是 3 参数接口
		body.take_damage(gravitation_damage_amount, belonger.character_type, belonger)

func _handle_escaping_bodies(current_targets: Array[Node2D]) -> void:
	for old_body in captured_bodies:
		if not is_instance_valid(old_body): continue
		if old_body not in current_targets:
			if old_body.has_method("recover_from_gravity"):
				old_body.recover_from_gravity()

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
func play_idle() -> void:
	if anim.current_animation != "Gravitataion_Shock":
		anim.play("Gravitation_Idle") 

func _reset_weapon_state() -> void:
	if anim.current_animation == "Gravitataion_Attract":
		stop_gravity_firing()
		play_idle()
	elif anim.current_animation == "":
		play_idle()
		if hitbox.monitoring: stop_gravity_firing()
#endregion

#region 视觉特效逻辑
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
