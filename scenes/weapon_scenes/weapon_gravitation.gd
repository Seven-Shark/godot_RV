extends Node2D

#region 节点引用
@onready var anim = $AnimationPlayer
@onready var hitbox: Area2D = $Weapon_Hitbox
@onready var shockwave_vfx: ColorRect = $Weapon_Hitbox/ShockwaveVFX 
@onready var gravity_viz: Polygon2D = $Weapon_Hitbox/GravityViz 
#endregion

#region 战斗参数配置
@export_group("Combat Stats")
@export var gravitation_damage_amount : int = 10     ## 引力波每跳伤害
@export var shock_damage_amount : int = 50           ## 震荡波单次伤害
@export var gravity_force : float = 400.0            ## 引力波吸附力度
@export var damage_interval : float = 0.5            ## 引力波伤害间隔时间
@export var shock_knockback_force : float = 1200.0   ## 震荡波击退力度
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
var belonger: CharacterBase           ## 武器持有者引用
var damage_timer : float = 0.0        ## [内部] 伤害触发计时器
var captured_bodies: Array[Node2D] = [] ## [内部] 当前被引力捕获的物体列表
#endregion

#region 生命周期
func _ready():
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.monitoring = false
	hitbox.visible = false
	
	if shockwave_vfx:
		shockwave_vfx.visible = false
		
	# 初始化可视化
	if gravity_viz:
		gravity_viz.visible = false # 默认隐藏，需要时再显示
		gravity_viz.color = Color(0.0, 1.0, 1.0, 0.3)
		_update_gravity_viz_shape()

func _physics_process(delta: float) -> void:
	_update_cooldowns(delta)
	_handle_input(delta)
#endregion

#region 核心循环逻辑
func _update_cooldowns(delta: float) -> void:
	if shock_cooldown_timer > 0:
		shock_cooldown_timer -= delta

func _handle_input(delta: float) -> void:
	var is_firing_shock = GameInputEvents.is_main_attack_held()    
	var is_firing_gravity = GameInputEvents.is_special_attack_held() 
	
	if is_firing_shock and not is_firing_gravity:
		_try_fire_shockwave()
	elif is_firing_gravity:
		_process_gravity_behavior(delta)
	else:
		_reset_weapon_state()
#endregion

#region 调试与参数调整 (HUD 接口)
func set_attack_angle(new_angle: float):
	shockwave_angle = new_angle
	if shockwave_vfx and shockwave_vfx.material:
		(shockwave_vfx.material as ShaderMaterial).set_shader_parameter("sector_angle_degrees", new_angle)
	_update_gravity_viz_shape()

func set_attack_radius(new_radius: float):
	var collision = hitbox.get_node_or_null("CollisionShape2D")
	if collision and collision.shape is CircleShape2D:
		collision.shape.radius = new_radius
	
	if shockwave_vfx:
		var diameter = new_radius * 2.0
		shockwave_vfx.size = Vector2(diameter, diameter)
		shockwave_vfx.position = Vector2(-new_radius, -new_radius) 
		
	_update_gravity_viz_shape()

## 【核心辅助函数】判断物体是否在扇形角度内
func _is_in_attack_angle(target_body: Node2D) -> bool:
	var direction_to_target = (target_body.global_position - global_position).normalized()
	# 使用 Hitbox 的朝向，因为它由 WeaponAdmin 控制旋转
	var weapon_forward = hitbox.global_transform.x.normalized()
	var angle_diff = rad_to_deg(weapon_forward.angle_to(direction_to_target))
	return abs(angle_diff) <= (shockwave_angle / 2.0)
#endregion

#region 可视化辅助功能
func _update_gravity_viz_shape():
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

## 【新增】左键攻击时闪烁可视化区域
func _flash_attack_viz():
	if not gravity_viz: return
	
	# 瞬间显示
	gravity_viz.visible = true
	gravity_viz.modulate.a = 1.0
	
	# 创建一个独立的 Tween 来让它淡出
	var tween = create_tween()
	tween.tween_property(gravity_viz, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): 
		gravity_viz.visible = false
		gravity_viz.modulate.a = 1.0 # 恢复透明度给右键用
	)
#endregion

#region 震荡波行为 (Shockwave)
func _try_fire_shockwave():
	if shock_cooldown_timer > 0: return
	if anim.current_animation == "Gravitataion_Attract": return 
	play_attack()
	shock_cooldown_timer = shock_fire_interval

func play_attack():
	anim.play("Gravitataion_Shock")
	trigger_shockwave_vfx()
	# 【修复问题1】左键攻击时，闪烁显示扇形区域，方便玩家确认范围
	_flash_attack_viz()

func _on_hitbox_body_entered(body: Node2D):
	if body == belonger: return
	if anim.current_animation != "Gravitataion_Shock": return
	
	if not _is_in_attack_angle(body): return
	
	if body.has_method("take_damage"):
		body.take_damage(shock_damage_amount, belonger.character_type, belonger)
		var knockback_dir = (body.global_position - belonger.global_position).normalized()
		if body is ObjectBase and body.has_method("trigger_shockwave_shake"):
			body.trigger_shockwave_shake(knockback_dir)
		elif body is CharacterBase and body.has_method("apply_knockback"):
			body.apply_knockback(knockback_dir, shock_knockback_force)
#endregion

#region 引力波行为 (Gravity)
func _process_gravity_behavior(delta: float):
	if anim.current_animation != "Gravitataion_Attract":
		play_holdattack()
	process_gravity_tick(delta)

func play_holdattack():
	anim.play("Gravitataion_Attract")
	if gravity_viz: gravity_viz.visible = true

func process_gravity_tick(delta: float):
	if not hitbox.monitoring:
		hitbox.visible = true
		hitbox.monitoring = true
	
	# 【修复问题2】微小的抖动，强制唤醒物理引擎检测
	# 即使鼠标不动，这行代码也会让 Godot 认为 Hitbox 动了，从而刷新重叠列表
	hitbox.position.x = 0.001 if Engine.get_physics_frames() % 2 == 0 else -0.001
	
	damage_timer -= delta
	var can_deal_damage = damage_timer <= 0
	if can_deal_damage:
		damage_timer = damage_interval 
	
	var current_bodies = hitbox.get_overlapping_bodies()
	var current_targets: Array[Node2D] = []
	
	for body in current_bodies:
		if body == belonger: continue 
		
		# 扇形检测
		if not _is_in_attack_angle(body):
			continue
		
		if body is PickupItem:
			if not body.is_being_absorbed:
				body.start_absorbing(belonger)
			continue
		
		if body is ObjectBase:
			current_targets.append(body)
			_apply_gravity_to_object(body, can_deal_damage)
				
		elif body is CharacterBase and body.has_method("take_damage"):
			if can_deal_damage:
				body.take_damage(gravitation_damage_amount, belonger.character_type, belonger)

	_handle_escaping_bodies(current_targets)
	captured_bodies = current_targets.duplicate()

func _apply_gravity_to_object(body: ObjectBase, can_damage: bool):
	var direction = (belonger.global_position - body.global_position).normalized()
	
	if body is RigidBody2D:
		body.apply_central_force(direction * gravity_force * body.mass * 2.0)
	
	body.apply_gravity_visual(belonger.global_position)
	
	if can_damage and body.stats:
		body.take_damage(gravitation_damage_amount, belonger.character_type, belonger)

func _handle_escaping_bodies(current_targets: Array[Node2D]):
	for old_body in captured_bodies:
		if not is_instance_valid(old_body): continue
		if old_body not in current_targets:
			if old_body.has_method("recover_from_gravity"):
				old_body.recover_from_gravity()

func stop_gravity_firing():
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
func play_idle():
	if anim.current_animation != "Gravitataion_Shock":
		anim.play("Gravitation_Idle") 

func _reset_weapon_state():
	if anim.current_animation == "Gravitataion_Attract":
		stop_gravity_firing()
		play_idle()
	elif anim.current_animation == "":
		play_idle()
		if hitbox.monitoring: stop_gravity_firing()
#endregion

#region 视觉特效逻辑
func trigger_shockwave_vfx():
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
