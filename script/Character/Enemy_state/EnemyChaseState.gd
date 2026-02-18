@icon("res://Resource/Icon/StateSprite.png")
extends EnemyState
class_name EnemyChaseState

func enter() -> void:
	# [修改] 开启斥力计算，允许追逐时挤开队友
	enemy.is_separation_active = true

	# 动画容错
	if enemy.sprite.sprite_frames.has_animation("Run"):
		anim.play("Run")
	else:
		anim.play("Walk")

func exit() -> void:
	# 退出追逐时，强制将导航代理的目标设为自己脚下，防止惯性
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
	
	enemy.process_navigation_movement(chase_speed)

func _on_next_transitions() -> void:
	if not enemy.is_aggro_active:
		transition.emit("Patrol")
		return
	
	if is_instance_valid(enemy.current_target):
		var dist = enemy.global_position.distance_to(enemy.current_target.global_position)
		
		# 进入攻击范围
		if dist <= enemy.attack_distance:
			transition.emit("Attack")
