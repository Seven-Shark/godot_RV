@icon("res://Resource/Icon/StateSprite.png")
extends EnemyState
class_name EnemyPatrolState

#region 内部变量
var _wait_timer: float = 0.0
var _is_waiting: bool = false 

# [修改] 防卡死检测相关变量
var _stuck_timer: float = 0.0 ## 卡死计时器
var _stuck_check_pos: Vector2 = Vector2.ZERO ## 上一次记录的检测位置
var _stuck_stage: int = 0 ## 卡死处理阶段 (0: 正常, 1: 已尝试重随)
#endregion

#region 状态生命周期
func enter() -> void:
	enemy.is_separation_active = true
	_is_waiting = false
	
	# 重置所有状态
	_reset_stuck_check(true)
	
	enemy.set_navigation_target_to_patrol_point()
	anim.play("Walk")

func exit() -> void:
	enemy.velocity = Vector2.ZERO

func _on_physics_process(delta: float) -> void:
	# 逻辑分支 1: 正在等待
	if _is_waiting:
		_wait_timer -= delta
		if _wait_timer <= 0:
			_is_waiting = false
			_reset_stuck_check(true) # 开始走路，完全重置检测
			enemy.set_navigation_target_to_patrol_point()
			anim.play("Walk")
			
	# 逻辑分支 2: 正在移动
	else:
		var has_arrived = enemy.process_navigation_movement(enemy.stats.base_walk_speed * 0.5)
		
		# --- [核心逻辑] 分级防卡死检测系统 ---
		if enemy.patrol_mode == Enemy.PatrolMode.GLOBAL_RANDOM:
			# 检测是否还在小范围内
			if enemy.global_position.distance_to(_stuck_check_pos) < enemy.stuck_check_radius:
				_stuck_timer += delta
				
				# 判断当前处于哪个阶段
				if _stuck_stage == 0:
					# [阶段 1] 正常尝试：超过 2秒
					if _stuck_timer >= enemy.stuck_retry_time:
						# print("卡死阶段 1：尝试重新随机目标")
						enemy.set_navigation_target_to_patrol_point() # 换个随机点试试
						_stuck_stage = 1 # 标记进入阶段 1
						_reset_stuck_check(false) # 重置计时和位置，但不重置阶段
						
				elif _stuck_stage == 1:
					# [阶段 2] 深度卡死：换了点后，又过了 1.5秒 还在原地
					if _stuck_timer >= enemy.stuck_escape_time:
						print(">>> 卡死阶段 2：执行反向逃逸！")
						var escape_point = enemy.get_escape_patrol_point() # 强制反向
						enemy.set_navigation_target(escape_point)
						_reset_stuck_check(true) # 彻底重置回阶段 0
			else:
				# 成功走出了范围，彻底重置
				_reset_stuck_check(true)
		# ---------------------------------
		
		if has_arrived:
			_is_waiting = true
			_wait_timer = randf_range(enemy.patrol_wait_min, enemy.patrol_wait_max)
			enemy.velocity = Vector2.ZERO 
			anim.play("Idle")

func _on_next_transitions() -> void:
	if enemy.is_returning:
		transition.emit("Return")
		return

	if enemy.is_aggro_active:
		transition.emit("Chase")
#endregion

#region 辅助方法
## 重置防卡死检测
## @param full_reset: 是否完全重置 (包括阶段)。如果只是从阶段1过渡到阶段2的计时重置，传 false
func _reset_stuck_check(full_reset: bool = true) -> void:
	_stuck_timer = 0.0
	_stuck_check_pos = enemy.global_position
	if full_reset:
		_stuck_stage = 0
#endregion
