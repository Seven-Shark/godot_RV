extends Node2D

#region 节点引用
@onready var anim = $AnimationPlayer
@onready var hitbox: Area2D = $Weapon_Hitbox
@onready var shockwave_vfx: ColorRect = $Weapon_Hitbox/ShockwaveVFX 
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
	# 初始化 Hitbox 状态
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.monitoring = false
	hitbox.visible = false
	
	# 初始化特效状态
	if shockwave_vfx:
		shockwave_vfx.visible = false

func _physics_process(delta: float) -> void:
	# 1. 更新冷却时间
	_update_cooldowns(delta)
	
	# 2. 处理输入与状态决策
	_handle_input(delta)
#endregion

#region 核心循环逻辑
# 更新所有冷却计时器
func _update_cooldowns(delta: float) -> void:
	if shock_cooldown_timer > 0:
		shock_cooldown_timer -= delta

# 处理玩家输入并分发行为
func _handle_input(delta: float) -> void:
	# 获取输入状态 (依赖 GameInputEvents)
	var is_firing_shock = GameInputEvents.is_main_attack_held()    # 左键按住
	var is_firing_gravity = GameInputEvents.is_special_attack_held() # 右键按住
	
	# 优先级决策：左键(震荡) > 右键(引力) > 待机
	if is_firing_shock and not is_firing_gravity:
		_try_fire_shockwave()
		
	elif is_firing_gravity:
		_process_gravity_behavior(delta)
		
	else:
		_reset_weapon_state()
#endregion

#region 震荡波行为 (Shockwave)
# 尝试发射震荡波 (包含冷却和动画状态检查)
func _try_fire_shockwave():
	# 检查冷却 & 防止打断引力波起手
	if shock_cooldown_timer > 0: return
	if anim.current_animation == "Gravitataion_Attract": return 
	
	# 执行发射
	play_attack()
	shock_cooldown_timer = shock_fire_interval

# 播放攻击动画并触发特效
func play_attack():
	# 强制重播动画以支持连发
	anim.play("Gravitataion_Shock")
	trigger_shockwave_vfx()

# 震荡波命中判定回调
func _on_hitbox_body_entered(body: Node2D):
	if body == belonger: return
	if anim.current_animation != "Gravitataion_Shock": return
	
	if body.has_method("take_damage"):
		# print(name + " 震荡波命中:", body.name)
		body.take_damage(shock_damage_amount, belonger.character_type, belonger)
		
		# 计算击退方向 (从中心向外)
		var knockback_dir = (body.global_position - belonger.global_position).normalized()
		
		# 应用击退效果 (区分物体和角色)
		if body is ObjectBase and body.has_method("trigger_shockwave_shake"):
			body.trigger_shockwave_shake(knockback_dir)
		elif body is CharacterBase and body.has_method("apply_knockback"):
			body.apply_knockback(knockback_dir, shock_knockback_force)
#endregion

#region 引力波行为 (Gravity)
# 执行引力波逻辑 (持续型，每帧调用)
func _process_gravity_behavior(delta: float):
	# 1. 播放动画
	if anim.current_animation != "Gravitataion_Attract":
		play_holdattack()
	
	# 2. 执行每帧的物理吸附逻辑
	process_gravity_tick(delta)

# 播放持续施法动画
func play_holdattack():
	anim.play("Gravitataion_Attract")

# 引力波物理计算核心
func process_gravity_tick(delta: float):
	if not hitbox.monitoring:
		hitbox.visible = true
		hitbox.monitoring = true
	
	# 更新伤害计时器
	damage_timer -= delta
	var can_deal_damage = damage_timer <= 0
	if can_deal_damage:
		damage_timer = damage_interval 
	
	var current_bodies = hitbox.get_overlapping_bodies()
	var current_targets: Array[Node2D] = []
	
	for body in current_bodies:
		if body == belonger: continue 
		
		# 1. 如果是掉落物资源，直接触发吸附
		if body is PickupItem:
			# 只要还没被吸附，就开始吸
			if not body.is_being_absorbed:
				body.start_absorbing(belonger)
			# 资源不需要伤害计算，也不需要加入 captured_bodies (因为它是飞过来的，不需要武器持续施力)
			continue
		
		# 分类处理吸引和伤害
		if body is ObjectBase:
			current_targets.append(body)
			_apply_gravity_to_object(body, can_deal_damage)
				
		elif body is CharacterBase and body.has_method("take_damage"):
			if can_deal_damage:
				body.take_damage(gravitation_damage_amount, belonger.character_type, belonger)

	# 检查逃逸物体 (恢复状态)
	_handle_escaping_bodies(current_targets)
	
	captured_bodies = current_targets.duplicate()

# [辅助] 对物体应用引力物理和视觉效果
func _apply_gravity_to_object(body: ObjectBase, can_damage: bool):
	var direction = (belonger.global_position - body.global_position).normalized()
	
	# 物理吸引
	if body is RigidBody2D:
		body.apply_central_force(direction * gravity_force * body.mass * 2.0)
	
	# 视觉拉伸
	body.apply_gravity_visual(belonger.global_position)
	
	# 伤害
	if can_damage and body.stats:
		body.take_damage(gravitation_damage_amount, belonger.character_type, belonger)

# [辅助] 处理逃逸物体 (恢复原状)
func _handle_escaping_bodies(current_targets: Array[Node2D]):
	for old_body in captured_bodies:
		if not is_instance_valid(old_body): continue
		if old_body not in current_targets:
			if old_body.has_method("recover_from_gravity"):
				old_body.recover_from_gravity()

# 停止引力波 (重置状态)
func stop_gravity_firing():
	hitbox.visible = false
	hitbox.monitoring = false
	
	# 恢复所有被吸住物体的形状
	if captured_bodies.size() > 0:
		for body in captured_bodies:
			if is_instance_valid(body) and body.has_method("recover_from_gravity"):
				body.recover_from_gravity()
		captured_bodies.clear()
#endregion

#region 通用状态管理
# 播放待机动画
func play_idle():
	# 只有不在播放攻击动画时才切回 Idle
	if anim.current_animation != "Gravitataion_Shock":
		anim.play("Gravitation_Idle") 

# 重置武器状态 (松开按键时调用)
func _reset_weapon_state():
	# 如果当前在播放引力波，才需要切回 Idle
	if anim.current_animation == "Gravitataion_Attract":
		stop_gravity_firing()
		play_idle()
	# 额外保险：如果完全没有任何动画在播放
	elif anim.current_animation == "":
		play_idle()
		if hitbox.monitoring: stop_gravity_firing()
#endregion

#region 视觉特效逻辑
# 触发震荡波空气扰动特效
func trigger_shockwave_vfx():
	if not shockwave_vfx or not shockwave_vfx.material: return
		
	shockwave_vfx.visible = true
	var mat = shockwave_vfx.material as ShaderMaterial
	
	# 设置参数
	mat.set_shader_parameter("radius_progress", 0.0)
	mat.set_shader_parameter("sector_angle_degrees", shockwave_angle)
	
	# 创建 Tween 动画
	var tween = create_tween()
	tween.tween_method(
		func(val): mat.set_shader_parameter("radius_progress", val), 
		0.0, 1.0, shockwave_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
