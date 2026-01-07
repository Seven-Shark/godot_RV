extends CharacterBase
class_name Enemy

## 敌人基础类 (Enemy)
##
## 继承自 CharacterBase，实现了具体的 AI 行为逻辑，包括：
## 1. 自动索敌与朝向控制
## 2. 三段式距离控制（追击、站桩、后退）
## 3. 群体行为（防重叠分离力）
## 4. 物理交互（被玩家推挤、击退）


# 1. 导出变量 (AI 配置)

#region AI 距离控制
@export_group("AI Distances")
@export var attack_distance: float = 100.0  ## 停止距离：大于此距离追击，处于此距离内停止
@export var retreat_distance: float = 70.0  ## 后退距离：小于此距离主动后退 (形成 70-100 的缓冲死区)
#endregion

#region 物理力参数
@export_group("Physics Forces")
@export var separation_force: float = 500.0 ## 分离力度：防止敌人重叠的排斥力
@export var push_force: float = 800.0       ## 推挤力度：模拟被玩家推开的力
@export var push_threshold: float = 80.0    ## 推挤感应半径：必须 > (敌人半径 + 玩家半径)
#endregion

# 2. 生命周期
func _init() -> void:
	# 初始化阵营和索敌目标
	character_type = CharacterType.ENEMY
	target_types = [CharacterType.PLAYER]

func _ready() -> void:
	super._ready() # 调用父类初始化 (如血条连接)
	
	# [重要] 设置为浮动模式 (Floating)
	# 2D俯视角游戏必须使用此模式，否则物理引擎会计算重力和地板摩擦，
	# 导致“被玩家带着走”或“侧向推不动”的 Bug。
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	
	# 设置滑行角度 (0度表示稍微碰到墙就滑行，手感更顺滑)
	wall_min_slide_angle = 0.0


# 3. 核心循环 (Process)
#region 物理更新
func _physics_process(delta: float) -> void:
	# 1. 调用父类处理击退速度的自然衰减
	super._physics_process(delta) 
	
	var move_direction: Vector2 = Vector2.ZERO
	var current_move_speed: float = 0.0
	
	# 2. AI 决策逻辑 (仅在存活且有目标时执行)
	if current_target and not is_dead:
		var distance_to_target = global_position.distance_to(current_target.global_position)
		
		# --- 三段式移动逻辑 ---
		if distance_to_target > attack_distance:
			# [A] 追击阶段
			move_direction = (current_target.global_position - global_position).normalized()
			if stats: current_move_speed = stats.get_final_speed(false)
			
		elif distance_to_target < retreat_distance:
			# [B] 后退阶段 (解决粘连问题)
			move_direction = (global_position - current_target.global_position).normalized()
			# 后退速度打折 (0.6倍)，防止像弹簧一样弹射
			if stats: current_move_speed = stats.get_final_speed(false) * 0.6
		
		else:
			# [C] 缓冲死区 (70 ~ 100) -> 站桩
			move_direction = Vector2.ZERO
			current_move_speed = 0.0
			
		# [视觉] 始终面向目标 (独立于移动方向)
		_face_target()
	
	# 3. 计算额外的物理场力
	var separation_velocity = _calculate_separation_velocity() # 队友排斥力
	var push_velocity = _handle_player_push()                  # 玩家推挤力
	
	# 4. 速度融合计算
	var ai_velocity = move_direction * current_move_speed
	var final_velocity = Vector2.ZERO
	
	# 优先级判定：如果受到强力击退 (>50)，则暂时失去对身体的控制
	if knockback_velocity.length() > 50.0:
		final_velocity = knockback_velocity
	else:
		# 正常状态：AI移动 + 队友排斥 + 玩家推挤 + 击退余波
		final_velocity = ai_velocity + separation_velocity + push_velocity + knockback_velocity
	
	# 5. 应用最终速度并移动
	velocity = final_velocity
	move_and_slide()
#endregion

#region 逻辑更新
func _process(_delta) -> void:
	# 持续更新最近的目标
	var nearest_target = get_closest_target()
	
	# 如果目标发生变化，更新引用
	if nearest_target and nearest_target != current_target:
		current_target = nearest_target
	elif not nearest_target and current_target:
		current_target = null
	
	# 更新箭头指向 (父类方法)
	Target_Lock_On(nearest_target)
#endregion


# 4. 行为逻辑方法
#region 视觉表现
## 面向目标逻辑 (替代父类基于速度的 Turn)
## 作用：确保无论是在后退还是被击飞，脸始终朝向玩家
func _face_target():
	if not current_target or not sprite: return
	
	# 计算目标相对位置
	var to_target = current_target.global_position - global_position
	
	# 假定 flipped_horizontal=false 代表素材默认朝右
	var direction = -1 if flipped_horizontal else 1
	
	if to_target.x < 0:
		sprite.scale.x = -direction # 目标在左，翻转
	else:
		sprite.scale.x = direction  # 目标在右，正常
#endregion

#region 物理交互计算
## 计算被玩家推动的模拟力
## 作用：解决 CharacterBody2D 默认无法被推动的问题，以及单向推动的 Bug
func _handle_player_push() -> Vector2:
	# 直接从侦测区域获取物体，不依赖锁敌逻辑
	var bodies = detection_Area.get_overlapping_bodies()
	var final_push = Vector2.ZERO
	
	for body in bodies:
		# 筛选玩家
		if body is CharacterBase and body.character_type == CharacterType.PLAYER:
			var distance = global_position.distance_to(body.global_position)
			
			# 只有进入“斥力场”阈值内才产生推力
			if distance < push_threshold and distance > 0:
				# 计算推离方向：从玩家指向敌人
				var push_dir = (global_position - body.global_position).normalized()
				
				# 动态权重：距离越近，推力越大 (1.0 -> 0.0)
				# 模拟弹簧挤压手感
				var power_weight = 1.0 - (distance / push_threshold)
				
				final_push += push_dir * push_force * power_weight
	
	return final_push

## 计算群体分离力 (Boids Separation)
## 作用：防止多个敌人重叠在一起
func _calculate_separation_velocity() -> Vector2:
	var force = Vector2.ZERO
	var bodies = detection_Area.get_overlapping_bodies()
	var neighbor_count = 0
	
	for body in bodies:
		# 筛选其他的敌人 (排除自己)
		if body is Enemy and body != self:
			var difference = global_position - body.global_position
			var distance = difference.length()
			
			# 敏感半径：小于 50 像素时产生强烈排斥
			if distance < 50.0 and distance > 0:
				force += difference.normalized() / distance
				neighbor_count += 1
	
	if neighbor_count > 0:
		force = force / neighbor_count
		return force * separation_force
	
	return Vector2.ZERO
#endregion
