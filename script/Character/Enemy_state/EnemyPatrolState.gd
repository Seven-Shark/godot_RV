@icon("res://Resource/Icon/StateSprite.png")
extends EnemyState
class_name EnemyPatrolState

# 内部变量
var _wait_timer: float = 0.0
var _is_waiting: bool = false # 标记当前是在走路还是在发呆

func enter() -> void:
	# 进入状态时，直接开始寻路
	_is_waiting = false
	enemy.set_navigation_target_to_patrol_point()
	anim.play("Walk")

func exit() -> void:
	enemy.velocity = Vector2.ZERO

func _on_physics_process(delta: float) -> void:
	# 逻辑分支 1: 正在等待
	if _is_waiting:
		_wait_timer -= delta
		if _wait_timer <= 0:
			# 等待结束，寻找新目标，切换回走路模式
			_is_waiting = false
			enemy.set_navigation_target_to_patrol_point()
			anim.play("Walk")
			
	# 逻辑分支 2: 正在移动
	else:
		# 调用 Enemy 封装好的导航方法
		# 它会处理寻路、避障、朝向，并返回是否到达
		var has_arrived = enemy.process_navigation_movement(enemy.stats.base_walk_speed * 0.5)
		
		if has_arrived:
			# 到达目的地，开始等待
			_is_waiting = true
			_wait_timer = randf_range(enemy.patrol_wait_min, enemy.patrol_wait_max)
			enemy.velocity = Vector2.ZERO # 确保停稳
			anim.play("Idle")

func _on_next_transitions() -> void:
	if enemy.is_returning:
		transition.emit("Return")
		return

	if enemy.is_aggro_active:
		transition.emit("Chase")
