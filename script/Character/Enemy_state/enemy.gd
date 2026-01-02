extends CharacterBase
class_name Enemy

# --- 配置参数 ---
@export var attack_distance: float = 100.0  # 停止距离
@export var retreat_distance: float = 70.0  # 后退距离
@export var separation_force: float = 500.0 # 敌人间的分离力度
@export var push_force: float = 800.0       # 【新增】玩家推敌人的力度

func _init() -> void:
	character_type = CharacterType.ENEMY
	target_types = [CharacterType.PLAYER]

func _ready() -> void:
	super._ready()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta) 
	
	var move_direction = Vector2.ZERO
	var current_move_speed = 0.0
	
	# 1. AI 决策逻辑
	if current_target:
		var distance_to_target = global_position.distance_to(current_target.global_position)
		
		if distance_to_target > attack_distance:
			# [追击]
			move_direction = (current_target.global_position - global_position).normalized()
			if stats: current_move_speed = stats.get_final_speed(false)
			
		elif distance_to_target < retreat_distance:
			# [主动后退]
			move_direction = (global_position - current_target.global_position).normalized()
			if stats: current_move_speed = stats.get_final_speed(false) * 0.6
		else:
			# [站桩]
			move_direction = Vector2.ZERO
			current_move_speed = 0.0
			
		# 【修复问题 2】：始终面向目标，而不是根据速度转向
		_face_target()
	
	# 2. 计算额外的物理力
	var separation_velocity = _calculate_separation_velocity() # 防叠怪
	var push_velocity = _handle_player_push()                  # 【修复问题 1】被玩家推动
	
	# 3. 速度融合
	var ai_velocity = move_direction * current_move_speed
	var final_velocity = Vector2.ZERO
	
	# 如果处于大击退状态，优先处理击退
	if knockback_velocity.length() > 50.0:
		final_velocity = knockback_velocity
	else:
		# 最终速度 = AI意图 + 队友排斥 + 玩家推挤 + 击退余波
		final_velocity = ai_velocity + separation_velocity + push_velocity + knockback_velocity
	
	velocity = final_velocity
	move_and_slide()

# (process 函数保持不变)
func _process(_delta) -> void:
	var nearest_target = get_closest_target()
	if nearest_target and nearest_target != current_target:
		current_target = nearest_target
	elif not nearest_target and current_target:
		current_target = null
	Target_Lock_On(nearest_target)

# --- 【新增】逻辑：面向目标 ---
# 替代父类的 Turn()，不再依赖 velocity
func _face_target():
	if not current_target or not sprite: return
	
	# 判断目标在我的左边还是右边
	var to_target = current_target.global_position - global_position
	
	# 假设 flipped_horizontal = false 代表默认朝右 (Scale X = 1)
	# 如果你的美术资源默认朝左，请反转这里的逻辑
	var direction = -1 if flipped_horizontal else 1
	
	if to_target.x < 0:
		sprite.scale.x = -direction # 目标在左，翻转
	else:
		sprite.scale.x = direction  # 目标在右，正常

# --- 【新增】逻辑：被玩家推动 ---
# 解决“推不动”或“只能单向推”的问题
# --- 【修正版】逻辑：被玩家推动 ---
func _handle_player_push() -> Vector2:
	# 1. 不要依赖 current_target，而是主动在侦测范围内找玩家
	# 这样即使敌人没“看见”你（没锁敌），你撞它，它也会被推开
	var bodies = detection_Area.get_overlapping_bodies()
	
	# 2. 增大感应阈值
	# 假设你的 Sprite 宽约 30-40，加上玩家的宽度
	# 这个值必须 > (玩家碰撞半径 + 敌人碰撞半径)
	# 建议设为 60.0 或更大，形成一个“斥力场”
	var push_threshold = 80.0 
	
	var final_push = Vector2.ZERO
	
	for body in bodies:
		# 找到玩家 (确保 body 是 CharacterBase 且类型是 PLAYER)
		if body is CharacterBase and body.character_type == CharacterType.PLAYER:
			var distance = global_position.distance_to(body.global_position)
			
			if distance < push_threshold and distance > 0:
				# 计算推离方向：从玩家指向敌人
				var push_dir = (global_position - body.global_position).normalized()
				
				# 3. 增加力度的动态权重
				# 距离越近，推力越大（模拟弹簧挤压感）
				# 1.0 表示贴脸，0.0 表示刚好在阈值边缘
				var power_weight = 1.0 - (distance / push_threshold)
				
				# 叠加推力 (如果未来有联机多个玩家推，这样也能处理)
				final_push += push_dir * push_force * power_weight
	
	return final_push

# --- 逻辑：队友排斥 ---
func _calculate_separation_velocity() -> Vector2:
	var force = Vector2.ZERO
	var bodies = detection_Area.get_overlapping_bodies()
	var neighbor_count = 0
	
	for body in bodies:
		if body is Enemy and body != self:
			var difference = global_position - body.global_position
			var distance = difference.length()
			
			if distance < 50.0 and distance > 0:
				force += difference.normalized() / distance
				neighbor_count += 1
	
	if neighbor_count > 0:
		force = force / neighbor_count
		return force * separation_force
	
	return Vector2.ZERO
