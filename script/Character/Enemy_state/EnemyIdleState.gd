@icon("res://Resource/Icon/StateSprite.png")
extends EnemyState
class_name EnemyIdleState

func enter() -> void:
	anim.play("Idle")
	enemy.velocity = Vector2.ZERO

func _on_physics_process(_delta: float) -> void:
	# 摩擦力停车
	enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, 10.0)

func _on_next_transitions() -> void:
	# 1. [最高优先级] 检查是否触发了强制返航 (定点巡逻超出范围)
	if enemy.is_returning:
		transition.emit("Return")
		return

	# 2. [次高优先级] 检查是否有仇恨 (发现玩家)
	if enemy.is_aggro_active:
		transition.emit("Chase")
		return
		
	# 3. [默认行为] 如果既没返航也没仇恨，就去巡逻
	# (具体的随机移动或等待逻辑，交给 Patrol 状态处理)
	transition.emit("Patrol")
