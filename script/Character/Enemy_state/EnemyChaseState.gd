@icon("res://Resource/Icon/StateSprite.png")
extends EnemyState
class_name EnemyChaseState

func enter() -> void:
	# [修改] 使用 Run 动画，如果没有请确保 AnimationPlayer 里有对应的 key
	anim.play("Walk")

func exit() -> void:
	# [关键] 退出追逐时，强制将导航代理的目标设为自己脚下，防止惯性
	if enemy.nav_agent:
		enemy.nav_agent.target_position = enemy.global_position
	enemy.velocity = Vector2.ZERO

func _on_physics_process(_delta: float) -> void:
	if not is_instance_valid(enemy.current_target) or enemy.current_target.is_dead:
		enemy.is_aggro_active = false
		return

	# 1. 更新导航目标
	enemy.set_navigation_target(enemy.current_target.global_position)
	
	# 2. 执行移动 (追逐速度快一点)
	var chase_speed = 100.0
	if enemy.stats:
		chase_speed = enemy.stats.base_walk_speed * 1.2
	
	# [关键] 保存返回值，用于调试或判断
	enemy.process_navigation_movement(chase_speed)

func _on_next_transitions() -> void:
	if not enemy.is_aggro_active:
		transition.emit("Patrol")
		return
	
	if is_instance_valid(enemy.current_target):
		var dist = enemy.global_position.distance_to(enemy.current_target.global_position)
		
		# [关键] 进入攻击范围
		if dist <= enemy.attack_distance:
			transition.emit("Attack")
