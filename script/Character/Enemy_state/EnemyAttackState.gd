@icon("res://Resource/Icon/StateSprite.png")
extends EnemyState
class_name EnemyAttackState

var is_attacking: bool = false

func enter() -> void:
	is_attacking = true
	# 1. 进状态瞬间刹车
	enemy.velocity = Vector2.ZERO
	# 2. 切断导航 (防止 NavigationAgent 继续施加避障速度)
	if enemy.nav_agent:
		enemy.nav_agent.set_velocity(Vector2.ZERO)
	
	anim.play("Idle")
	_perform_attack()

func exit() -> void:
	enemy.attack_visual.visible = false
	enemy.attack_area.monitoring = false
	is_attacking = false

# [新增] 必须添加这个，否则 Enemy.gd 的 physics_process 会继续使用旧速度
func _on_physics_process(delta: float) -> void:
	# 攻击时强制停止主动移动，但允许被队友推开（防重叠）和被击退
	# 我们不调用 process_navigation_movement，这样就不会有导航速度
	
	# 1. 始终面向目标 (增加攻击手感)
	if is_instance_valid(enemy.current_target):
		enemy.face_current_target()
		
		# 如果你想让红框也一直跟着玩家转，可以在这里更新 rotation
		# var dir = enemy.current_target.global_position - enemy.global_position
		# enemy.attack_pivot.rotation = dir.angle()

	# 2. 速度控制：
	# Enemy.gd 会在 _physics_process 里叠加 env_force (环境斥力) + knockback (击退)
	# 所以这里只要不给 velocity 赋值主动速度，它就只会受外力影响，实现了“攻击时不走动，但会挤开”
	enemy.velocity = Vector2.ZERO 

func _perform_attack() -> void:
	if not is_instance_valid(enemy.current_target):
		is_attacking = false
		return
	
	# 1. 锁定方向 (只在攻击开始瞬间锁定一次，类似黑魂的攻击机制)
	var dir = enemy.current_target.global_position - enemy.global_position
	enemy.attack_pivot.rotation = dir.angle()
	
	# 2. 显示预警
	enemy.attack_visual.visible = true
	enemy.attack_visual.size.x = 0
	enemy.attack_visual.color = Color(1.0, 0.2, 0.2, 0.5) 
	
	# 3. 蓄力
	var tween = create_safe_tween()
	tween.tween_property(enemy.attack_visual, "size:x", enemy.attack_range_length, enemy.charge_duration)
	tween.tween_callback(_on_damage_frame)

func _on_damage_frame() -> void:
	if not is_instance_valid(enemy): return

	# --- 闪烁特效 ---
	var flash_tween = create_safe_tween()
	flash_tween.tween_property(enemy.attack_visual, "color", Color(2.0, 2.0, 2.0, 1.0), 0.05)
	flash_tween.tween_property(enemy.attack_visual, "color", Color(1.0, 0.2, 0.2, 0.5), 0.05)
	
	# --- 伤害逻辑 ---
	enemy.attack_area.monitoring = true
	await get_tree().physics_frame 
	await get_tree().physics_frame 
	
	if not is_instance_valid(enemy): return
	
	var bodies = enemy.attack_area.get_overlapping_bodies()
	for body in bodies:
		if body == enemy: continue
		if body is CharacterBase and body.character_type == CharacterBase.CharacterType.PLAYER:
			body.take_damage(enemy.attack_damage, enemy.character_type, enemy)
			var knock_dir = Vector2.RIGHT.rotated(enemy.attack_pivot.rotation)
			body.apply_knockback(knock_dir, 300.0)
	
	enemy.attack_area.monitoring = false
	
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(enemy):
		enemy.attack_visual.visible = false
		is_attacking = false 

func _on_next_transitions() -> void:
	if not is_attacking:
		# 攻击结束，进入冷却状态 (如果你没有Cooldown状态，就切回 Chase 或 Idle)
		transition.emit("Chase") # 这里我暂时切回 Chase，你可以改成 Cooldown
