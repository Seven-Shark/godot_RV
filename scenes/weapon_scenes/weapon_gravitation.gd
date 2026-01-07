extends Node2D

@onready var anim = $AnimationPlayer
@onready var hitbox: Area2D = $Weapon_Hitbox
@onready var shockwave_vfx: ColorRect = $Weapon_Hitbox/ShockwaveVFX #引用特效shader
@export var gravitation_damage_amount : int = 10
@export var shock_damage_amount : int = 50 
@export var gravity_force : float = 400.0 
@export var damage_interval : float = 0.5 

#震荡波的基础击退力度
@export var shock_knockback_force : float = 1200.0


# --- 新增特效参数 ---
@export_group("Visual Effects")
@export var shockwave_duration: float = 0.3 # 特效扩散持续时间
@export var shockwave_angle: float = 90.0 # 【新增】扇形角度，设为与你 Hitbox 覆盖角度一致

var belonger: CharacterBase
var damage_timer : float = 0.0
var captured_bodies: Array[Node2D] = []

func _ready():
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	# 确保 ready 时关闭 hitbox，避免误触
	hitbox.monitoring = false
	hitbox.visible = false
	
	# --- 新增：确保特效初始是隐藏的 ---
	if shockwave_vfx:
		shockwave_vfx.visible = false

func play_idle():
	anim.play("Gravitation_Idle") 

# 这个函数只负责播放动画，具体的逻辑在 process_gravity_tick 里
func play_holdattack():
	anim.play("Gravitataion_Attract")

func play_attack():
	anim.play("Gravitataion_Shock")
# --- 新增：触发特效 ---
	trigger_shockwave_vfx()

#单次震荡波攻击
func _on_hitbox_body_entered(body: Node2D):
	
	if body == belonger:
		return
	
	if anim.current_animation != "Gravitataion_Shock":
		return
	
	# 2. 处理伤害与反馈
	if body.has_method("take_damage"):
		print(name + " 震荡波命中:", body.name)
		body.take_damage(shock_damage_amount, belonger.character_type, belonger)
		
		# --- 反馈逻辑 ---
		# 1. 计算击退方向 (从持有者指向受击者)
		var knockback_dir = (body.global_position - belonger.global_position).normalized()
		
		# 情况 A：打到了物件 (ObjectBase)
		if body is ObjectBase:
			# 调用物件专属的震荡回弹函数
			if body.has_method("trigger_shockwave_shake"):
				body.trigger_shockwave_shake(knockback_dir)
				
		# 情况 B：打到了敌人 (CharacterBase)
		# 调用角色的击退函数，传入方向和基础力度
		elif body is CharacterBase and body.has_method("apply_knockback"):
				body.apply_knockback(knockback_dir, shock_knockback_force)

# --- 专门供状态机调用的“每帧执行”函数 ---
func process_gravity_tick(delta: float):
	
	if not hitbox.monitoring and not hitbox.visible:
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
		
		# 处理 ObjectBase
		if body is ObjectBase:
			current_targets.append(body)
			# A. 物理吸引
			var direction = (belonger.global_position - body.global_position).normalized()
			if body is RigidBody2D:
				body.apply_central_force(direction * gravity_force * body.mass * 2.0)
			# B. 视觉拉伸
			body.apply_gravity_visual(belonger.global_position)
			# C. 伤害
			if can_deal_damage and body.stats:
				body.take_damage(gravitation_damage_amount, belonger.character_type, belonger)
				
		# 处理 CharacterBase
		elif body is CharacterBase and body.has_method("take_damage"):
			if can_deal_damage:
				body.take_damage(gravitation_damage_amount, belonger.character_type, belonger)

	# 检查逃逸物体
	for old_body in captured_bodies:
		if not is_instance_valid(old_body):
			continue
		
		if old_body not in current_targets:
			if old_body.has_method("recover_from_gravity"):
				old_body.recover_from_gravity()
	
	captured_bodies = current_targets.duplicate()

# --- 停止开火 (供状态机退出时调用) ---
# 把原本的 _stop_gravity_firing 改名并公开，或者直接用这个
func stop_gravity_firing():
	
	hitbox.visible = false
	hitbox.monitoring = false
	
	if anim.current_animation == "Gravitataion_Attract":
		play_idle()
	
	# 清理所有被抓取物体的状态
	if captured_bodies.size() > 0:
		for body in captured_bodies:
			if is_instance_valid(body) and body.has_method("recover_from_gravity"):
				body.recover_from_gravity()
		captured_bodies.clear()


# 新增功能：触发空气扰动特效
func trigger_shockwave_vfx():
	if not shockwave_vfx or not shockwave_vfx.material:
		return
		
	# 1. 准备工作：显示节点，获取材质
	shockwave_vfx.visible = true
	var mat = shockwave_vfx.material as ShaderMaterial
	
	# 确保从中心开始
	mat.set_shader_parameter("radius_progress", 0.0)
	
	# 2. 【新增】设置扇形角度
	# 这样你就可以在编辑器里调整 shockwave_angle 来匹配不同的武器
	mat.set_shader_parameter("sector_angle_degrees", shockwave_angle)
	
	# 2. 创建 Tween 动画
	var tween = create_tween()
	
	# 3. 动画过程：在 duration 时间内，将 radius_progress 从 0.0 变到 1.0
	# 使用 EASE_OUT 让波纹扩散速度一开始快，后面慢，更有冲击感
	tween.tween_method(
		func(val): mat.set_shader_parameter("radius_progress", val), # 设置参数的匿名函数
		0.0, # 起始值
		1.0, # 终止值
		shockwave_duration # 持续时间
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 4. 动画结束：隐藏节点，节省性能
	tween.chain().tween_callback(func(): shockwave_vfx.visible = false)
