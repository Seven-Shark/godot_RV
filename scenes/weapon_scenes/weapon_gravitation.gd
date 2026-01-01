extends Node2D

@onready var anim = $AnimationPlayer
@onready var hitbox: Area2D = $Weapon_Hitbox
@export var damage_amount : int = 10 
@export var gravity_force : float = 400.0 
@export var damage_interval : float = 0.5 

var belonger: CharacterBase
var damage_timer : float = 0.0
var captured_bodies: Array[Node2D] = []

func _ready():
	pass

func play_idle():
	anim.play("Gravitation_Idle") 

# 这个函数只负责播放动画，具体的逻辑在 process_gravity_tick 里
func play_holdattack():
	anim.play("Gravitataion_Attract")

func play_attack():
	anim.play("Gravitataion_Shock")

# --- 新增：专门供状态机调用的“每帧执行”函数 ---
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
				body.take_damage(damage_amount, belonger.character_type, belonger)
				
		# 处理 CharacterBase
		elif body is CharacterBase and body.has_method("take_damage"):
			if can_deal_damage:
				body.take_damage(damage_amount, belonger.character_type, belonger)

	# 检查逃逸物体
	for old_body in captured_bodies:
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
