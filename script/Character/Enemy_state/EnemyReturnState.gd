@icon("res://Resource/Icon/StateSprite.png")
extends EnemyState
class_name EnemyReturnState

# ------------------------------------------------------------------
# [关键修改] 使用 enter() 而不是 _on_enter()
# 这样父类 EnemyState._on_enter() 会先执行，帮你把 anim 赋值好
# ------------------------------------------------------------------
func enter() -> void:
	anim.play("Walk")
	# 确保重置当前速度，等待 Enemy.gd 接管
	enemy.velocity = Vector2.ZERO

# ------------------------------------------------------------------
# [关键修改] 使用 exit() 而不是 _on_exit()
# ------------------------------------------------------------------
func exit() -> void:
	# [恢复] 恢复不透明
	enemy.modulate.a = 1.0 
	enemy.velocity = Vector2.ZERO

func _on_physics_process(_delta: float) -> void:
	# 实际移动逻辑由 Enemy.gd 接管 (最高优先级)
	pass

func _on_next_transitions() -> void:
	# 检查 Enemy.gd 是否关闭了返航开关
	# (当怪物回到出生点附近时，Enemy.gd 会把 is_returning 设为 false)
	if not enemy.is_returning:
		transition.emit("Idle")
