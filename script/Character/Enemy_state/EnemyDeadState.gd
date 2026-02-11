@icon("res://Resource/Icon/StateSprite.png")
extends EnemyState
class_name EnemyDeadState

func enter() -> void:
	# 1. 彻底停转
	enemy.velocity = Vector2.ZERO
	
	# 2. 播放动画 (可选)
	# anim.play("Dead")
	print("Enemy 进入死亡状态，正在处理后事...")
	
	# 3. 禁用碰撞 (防止尸体挡路)
	var collider = enemy.get_node_or_null("CollisionShape2D")
	if collider: collider.set_deferred("disabled", true)
	
	# 4. 延迟销毁
	# 注意：这里不能用 create_safe_tween，因为状态不会退出了，直接用普通的 Timer
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(enemy):
		enemy.queue_free()

func _on_physics_process(_delta: float) -> void:
	# 死亡状态下禁止移动
	enemy.velocity = Vector2.ZERO
