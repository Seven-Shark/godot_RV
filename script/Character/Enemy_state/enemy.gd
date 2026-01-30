extends CharacterBase
class_name Enemy

## 敌人基础类 (Enemy)
##
## 继承自 CharacterBase，实现了具体的 AI 行为逻辑，包括：
## 1. 自动索敌与朝向控制 (定时刷新优化)
## 2. 三段式距离控制 (追击、站桩、后退)
## 3. 群体行为 (防重叠分离力) 与 物理交互 (玩家推挤)

#region 1. AI 距离配置
@export_group("AI Distances")
@export var attack_distance: float = 100.0      ## 停止距离：大于此距离追击，处于此距离内停止
@export var retreat_distance: float = 70.0      ## 后退距离：小于此距离主动后退
@export var target_update_interval: float = 0.2 ## 索敌刷新间隔(秒)，避免每一帧都遍历全图搜索
#endregion

#region 2. 物理力场配置
@export_group("Physics Forces")
@export var separation_force: float = 500.0     ## 分离力度：防止敌人重叠的排斥力
@export var push_force: float = 800.0           ## 推挤力度：模拟被玩家推开的力
@export var push_threshold: float = 80.0        ## 推挤感应半径：必须 > (敌人半径 + 玩家半径)
#endregion

#region 内部状态变量
var _target_check_timer: float = 0.0            ## [内部] 索敌倒计时器
#endregion

#region 生命周期
func _init() -> void:
	character_type = CharacterType.ENEMY
	target_types = [CharacterType.PLAYER]

func _ready() -> void:
	super._ready() # 调用父类初始化 (如血条连接)
	
	# [重要] 设置为浮动模式 (Floating)
	# 2D俯视角游戏必须使用此模式，避免重力和侧向摩擦问题
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
#endregion

#region 核心物理循环
## 主物理处理循环：包含击退、AI决策、环境力计算和最终移动
func _physics_process(delta: float) -> void:
	# 1. 父类处理击退速度的xz自然衰减
	super._physics_process(delta) 
	
	# 2. 定时刷新最近的目标 (性能优化：不要每帧都算)
	_update_target_logic(delta)

	# 3. 准备基础移动数据
	var move_vec: Vector2 = Vector2.ZERO
	var current_move_speed: float = 0.0
	
	# 4. AI 决策逻辑 (移动意图)
	if is_instance_valid(current_target) and not is_dead:
		var to_target = current_target.global_position - global_position
		var distance_to_target = to_target.length()
		
		# --- 三段式移动逻辑 ---
		if distance_to_target > attack_distance:
			# [A] 追击阶段
			move_vec = to_target.normalized()
			if stats: current_move_speed = stats.get_final_speed(false, delta)
			
		elif distance_to_target < retreat_distance:
			# [B] 后退阶段 (解决粘连问题)
			move_vec = -to_target.normalized()
			# 后退速度打折 (0.6倍)，防止像弹簧一样弹射
			if stats: current_move_speed = stats.get_final_speed(false, delta) * 0.6
		
		else:
			# [C] 缓冲死区 (70 ~ 100) -> 站桩
			move_vec = Vector2.ZERO
			current_move_speed = 0.0
			
		# [视觉] 始终面向目标
		_face_target()
	
	# 5. 计算环境力 (性能优化：合并循环)
	var env_velocity = _calculate_environment_forces()
	
	# 6. 速度融合计算
	var ai_velocity = move_vec * current_move_speed
	var final_velocity = Vector2.ZERO
	
	# 优先级判定：如果受到强力击退 (>50)，则暂时失去对身体的控制
	# 使用 length_squared > 2500 (50^2) 进行比较以优化性能
	if knockback_velocity.length_squared() > 2500.0:
		final_velocity = knockback_velocity
	else:
		# 正常状态：AI移动 + 环境力(分离/推挤) + 击退余波
		final_velocity = ai_velocity + env_velocity + knockback_velocity
	
	# 7. 应用最终速度并移动
	velocity = final_velocity
	move_and_slide()
#endregion

#region AI 逻辑方法
## [优化] 定时刷新索敌逻辑，避免每帧遍历场景
func _update_target_logic(delta: float) -> void:
			# 更新父类 UI 指示器
	Target_Lock_On(current_target)
	
	# 如果已经有目标且存活，就不需要频繁检测最近目标
	if is_instance_valid(current_target) and not current_target.is_dead:
		return

	_target_check_timer -= delta
	if _target_check_timer <= 0:
		_target_check_timer = target_update_interval
		
		# 执行耗时的索敌搜索
		var nearest = get_closest_target()
		
		# 更新锁定状态
		if nearest != current_target:
			current_target = nearest
		

#endregion

#region 物理计算方法
## [优化] 计算环境力 (分离力 + 推挤力)，合并循环以减少遍历开销
func _calculate_environment_forces() -> Vector2:
	if not detection_Area: return Vector2.ZERO
	
	var neighbors = detection_Area.get_overlapping_bodies()
	if neighbors.is_empty(): return Vector2.ZERO
	
	var total_separation = Vector2.ZERO
	var total_push = Vector2.ZERO
	var sep_count = 0
	
	for body in neighbors:
		if body == self: continue # 跳过自己
		
		# 计算基础向量和距离
		var diff = global_position - body.global_position
		var dist_sq = diff.length_squared() # 使用距离平方比较，性能更好
		
		# 1. 处理队友分离力 (Enemy)
		# 敏感半径 50.0 (平方后 2500.0)
		if body is Enemy and dist_sq < 2500.0 and dist_sq > 0.1:
			var dist = sqrt(dist_sq)
			total_separation += (diff / dist) # 归一化向量
			sep_count += 1
			
		# 2. 处理玩家推挤力 (Player)
		elif body is CharacterBase and body.character_type == CharacterType.PLAYER:
			var threshold_sq = push_threshold * push_threshold
			if dist_sq < threshold_sq and dist_sq > 0.1:
				var dist = sqrt(dist_sq)
				var push_dir = diff / dist # 从玩家指向敌人
				# 动态权重：距离越近，推力越大 (1.0 -> 0.0)
				var weight = 1.0 - (dist / push_threshold)
				total_push += push_dir * push_force * weight

	# 平均化分离力
	if sep_count > 0:
		total_separation = (total_separation / sep_count) * separation_force
		
	return total_separation + total_push
#endregion

#region 视觉表现
## 面向目标逻辑：确保无论如何移动，脸始终朝向目标
func _face_target() -> void:
	if not current_target or not sprite: return
	
	# 只根据 X 轴差值判断
	var diff_x = current_target.global_position.x - global_position.x
	
	# 防止垂直移动时频繁抖动 (阈值 1.0)
	if abs(diff_x) < 1.0: return 
	
	var default_facing = -1 if flipped_horizontal else 1
	
	if diff_x < 0:
		sprite.scale.x = -default_facing # 目标在左，翻转
	else:
		sprite.scale.x = default_facing  # 目标在右，正常
#endregion
