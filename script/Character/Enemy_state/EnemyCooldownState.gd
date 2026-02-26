extends NodeState
class_name EnemyStunState

## EnemyStunState.gd
## 职责：处理敌人的眩晕状态，强制打断一切动作、冻结移动，并等待恢复。

@export var enemy: Enemy ## 关联当前的敌人节点
@export var anim: AnimationPlayer ## 关联动画播放器，用于打断动画

func _on_enter() -> void:
	if not enemy: return
	
	print(">>> [State] 敌人进入强制眩晕状态！")
	
	# 1. 强制清空速度，防止滑步
	enemy.velocity = Vector2.ZERO
	
	# 2. 【核心】暴力没收攻击判定！防止动画挥到一半造成伤害
	if enemy.attack_area:
		enemy.attack_area.set_deferred("monitoring", false)
	if enemy.attack_visual:
		enemy.attack_visual.visible = false
		
	# 3. 强制打断当前的所有动画
	if anim:
		anim.stop() # 立即停止当前动画 (例如 Attack)
		
		# 如果你有专门的眩晕动画，请替换成 "Stun"
		if anim.has_animation("Stun"):
			anim.play("Stun")
		elif anim.has_animation("Idle"):
			anim.play("Idle")

func _on_physics_process(_delta: float) -> void:
	if not enemy: return
	
	# 持续锁死速度，但依然调用 move_and_slide 保证正常的重力碰撞
	enemy.velocity = Vector2.ZERO
	enemy.move_and_slide()

func _on_next_transitions() -> void:
	if not enemy: return
	
	# 当 Enemy.gd 里的 is_stunned 倒计时结束变为 false 时，退出眩晕状态
	if not enemy.is_stunned:
		transition.emit("Idle")

func _on_exit() -> void:
	print(">>> [State] 敌人脱离眩晕，恢复正常。")
	# 可以在这里做一些恢复处理，比如重置攻击冷却等
