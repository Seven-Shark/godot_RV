@icon("res://Resource/Icon/StateSprite.png")
extends EnemyState
class_name EnemyPatrolState

# 内部状态
var _is_moving: bool = false
var _wait_timer: float = 0.0
var _target_pos: Vector2

# ------------------------------------------------------------------
# [关键修改 1] 使用 enter() 而不是 _on_enter()
# 这样父类会先执行初始化(找到 enemy)，然后再调用这里
# ------------------------------------------------------------------
func enter() -> void:
	# 此时父类已经帮你把 enemy 赋值好了，直接用！
	_target_pos = enemy.get_next_patrol_point()
	_is_moving = true
	anim.play("Walk")

# ------------------------------------------------------------------
# [关键修改 2] 使用 exit() 而不是 _on_exit()
# 这样父类可以在你退出后，帮你自动清理 Tween
# ------------------------------------------------------------------
func exit() -> void:
	enemy.velocity = Vector2.ZERO

func _on_physics_process(delta: float) -> void:
	# 这里依然使用 _on_physics_process，因为父类没有把这个封装成虚函数
	# 如果父类也没有定义 _on_physics_process，这里直接写没问题
	# 如果父类定义了，建议在第一行加 super._on_physics_process(delta)
	
	if _is_moving:
		# --- 移动逻辑 ---
		var dir = (_target_pos - enemy.global_position).normalized()
		var dist = enemy.global_position.distance_to(_target_pos)
		
		if enemy.stats:
			enemy.velocity = dir * enemy.stats.base_walk_speed * 0.5
		
		enemy.move_and_slide()
		
		if enemy.sprite:
			if dir.x > 0: enemy.sprite.scale.x = 1
			elif dir.x < 0: enemy.sprite.scale.x = -1
		
		if dist < 10.0:
			_is_moving = false
			_wait_timer = randf_range(enemy.patrol_wait_min, enemy.patrol_wait_max)
			enemy.velocity = Vector2.ZERO
			anim.play("Idle")
			
	else:
		# --- 等待逻辑 ---
		_wait_timer -= delta
		if _wait_timer <= 0:
			_target_pos = enemy.get_next_patrol_point()
			_is_moving = true
			anim.play("Walk")

func _on_next_transitions() -> void:
	# 状态跳转逻辑保持不变
	if enemy.is_returning:
		transition.emit("Return")
		return

	if enemy.is_aggro_active:
		transition.emit("Chase")
