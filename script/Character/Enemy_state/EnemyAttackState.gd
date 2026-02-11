@icon("res://Resource/Icon/StateSprite.png")
extends EnemyState
class_name EnemyAttackState

var is_attacking: bool = false

func enter() -> void:
	is_attacking = true
	enemy.velocity = Vector2.ZERO
	anim.play("Idle")
	
	_perform_attack()

func exit() -> void:
	enemy.attack_visual.visible = false
	enemy.attack_area.monitoring = false
	is_attacking = false

func _perform_attack() -> void:
	if not is_instance_valid(enemy.current_target):
		is_attacking = false
		return
	
	# 1. 锁定方向
	var dir = enemy.current_target.global_position - enemy.global_position
	enemy.attack_pivot.rotation = dir.angle()
	
	# 2. 显示红框 (预警阶段)
	enemy.attack_visual.visible = true
	enemy.attack_visual.size.x = 0
	# 预警颜色：半透明红
	enemy.attack_visual.color = Color(1.0, 0.2, 0.2, 0.5) 
	
	# 3. 蓄力动画 Tween
	var tween = create_safe_tween()
	tween.tween_property(enemy.attack_visual, "size:x", enemy.attack_range_length, enemy.charge_duration)
	tween.tween_callback(_on_damage_frame)

func _on_damage_frame() -> void:
	# --- [新增功能 1：攻击闪烁] ---
	# 在伤害生效瞬间，把框变成亮白色，持续 0.1秒
	var flash_tween = create_safe_tween()
	flash_tween.tween_property(enemy.attack_visual, "color", Color(2.0, 2.0, 2.0, 1.0), 0.05) # 高亮白
	flash_tween.tween_property(enemy.attack_visual, "color", Color(1.0, 0.2, 0.2, 0.5), 0.05) # 恢复红
	
	# --- 伤害判定 ---
	enemy.attack_area.monitoring = true
	
	# [关键] 必须等待物理帧更新，否则 get_overlapping_bodies 可能拿不到最新数据
	await get_tree().physics_frame 
	await get_tree().physics_frame # 保险起见等两帧
	
	# 获取区域内的身体
	var bodies = enemy.attack_area.get_overlapping_bodies()
	# print("攻击判定框内物体数量: ", bodies.size()) # 调试用：看看有没有检测到玩家
	
	for body in bodies:
		# 排除敌人自己 (虽然 mask 设置对的话不需要这一步，但加上保险)
		if body == enemy: continue
		
		# [新增功能 2：确保玩家受伤]
		# 检查 body 是否为 Player 类，或者其父类 CharacterBase 且类型为 PLAYER
		if body is CharacterBase and body.character_type == CharacterBase.CharacterType.PLAYER:
			# print("击中玩家！造成伤害: ", enemy.attack_damage)
			body.take_damage(enemy.attack_damage, enemy.character_type, enemy)
			
			# 击退效果
			var knock_dir = Vector2.RIGHT.rotated(enemy.attack_pivot.rotation)
			body.apply_knockback(knock_dir, 300.0)
	
	# --- 清理 ---
	enemy.attack_area.monitoring = false
	
	# 等闪烁动画播放完再消失 (0.1s)
	await get_tree().create_timer(0.1).timeout
	
	enemy.attack_visual.visible = false
	is_attacking = false 

func _on_next_transitions() -> void:
	if not is_attacking:
		transition.emit("Cooldown")
