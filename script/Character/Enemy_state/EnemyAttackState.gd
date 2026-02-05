@icon("res://Resource/Icon/StateSprite.png")
extends NodeState
class_name EnemyAttackState

@export var enemy: Enemy
@export var anim: AnimatedSprite2D

var is_attacking: bool = false

func _on_enter() -> void:
	is_attacking = true
	enemy.velocity = Vector2.ZERO # 攻击时强制静止
	anim.play("Idle") # 或者蓄力动画
	
	_perform_attack()

func _perform_attack() -> void:
	if not is_instance_valid(enemy.current_target):
		is_attacking = false
		return
	
	# 1. 锁定方向 (只在开始瞬间锁定)
	var dir = enemy.current_target.global_position - enemy.global_position
	enemy.attack_pivot.rotation = dir.angle()
	
	# 2. 视觉表现 (Tween拉长红框)
	enemy.attack_visual.visible = true
	enemy.attack_visual.size.x = 0
	
	var tween = create_tween()
	tween.tween_property(enemy.attack_visual, "size:x", enemy.attack_range_length, enemy.charge_duration)
	tween.tween_callback(_on_damage_frame)

func _on_damage_frame() -> void:
	# 3. 伤害判定
	enemy.attack_area.monitoring = true
	await get_tree().physics_frame # 等待物理更新
	
	var bodies = enemy.attack_area.get_overlapping_bodies()
	for body in bodies:
		if body is CharacterBase and body.character_type == CharacterBase.CharacterType.PLAYER:
			body.take_damage(enemy.attack_damage, enemy.character_type, enemy)
			# 可选：击退玩家
			var knock_dir = Vector2.RIGHT.rotated(enemy.attack_pivot.rotation)
			body.apply_knockback(knock_dir, 300.0)
	
	# 4. 清理
	enemy.attack_area.monitoring = false
	enemy.attack_visual.visible = false
	is_attacking = false # 标记攻击动作结束

func _on_next_transitions() -> void:
	# 只有当攻击动作完全结束才切换
	if not is_attacking:
		transition.emit("cooldown")
