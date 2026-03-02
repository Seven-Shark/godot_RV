@icon("res://Resource/Icon/StateSprite.png")
extends EnemyState
class_name EnemyAttackState

## 敌人攻击状态 (EnemyAttackState)
## 职责：处理敌人蓄力、预警显示、伤害判定及攻击后的状态转移。

#region 1. 状态变量
var is_attacking: bool = false ## 标记当前是否处于攻击序列中
#endregion

#region 2. 状态生命周期

## [生命周期] 进入状态：停止移动、重置导航、播放动画并启动攻击流程。
func enter() -> void:
	is_attacking = true
	enemy.velocity = Vector2.ZERO # 进状态瞬间刹车
	
	if enemy.nav_agent:
		enemy.nav_agent.set_velocity(Vector2.ZERO) # 切断导航防止避障速度干扰
	
	anim.play("Idle")
	_perform_attack()

## [生命周期] 退出状态：清理视觉残留，强行关闭伤害监测。
func exit() -> void:
	enemy.attack_visual.visible = false
	enemy.attack_area.set_deferred("monitoring", false) # 安全关闭监测
	is_attacking = false

## [生命周期] 物理帧更新：强制保持静止（允许被挤开），并持续面向目标。
func _on_physics_process(_delta: float) -> void:
	if is_instance_valid(enemy.current_target):
		enemy.face_current_target() # 始终面向目标增加攻击手感

	enemy.velocity = Vector2.ZERO # 攻击时强制停止主动移动，仅允许外力叠加
#endregion

#region 3. 攻击流程控制

## [内部逻辑] 执行攻击序列：锁定攻击朝向、初始化预警 UI 并开启蓄力 Tween。
func _perform_attack() -> void:
	if not is_instance_valid(enemy.current_target):
		is_attacking = false
		return
	
	# 1. 锁定攻击方向
	var dir = enemy.current_target.global_position - enemy.global_position
	enemy.attack_pivot.rotation = dir.angle()
	
	# 2. 初始化预警视觉效果
	enemy.attack_visual.visible = true
	enemy.attack_visual.size.x = 0
	enemy.attack_visual.color = Color(1.0, 0.2, 0.2, 0.5) 
	
	# 3. 蓄力动画
	var tween = create_safe_tween()
	tween.tween_property(enemy.attack_visual, "size:x", enemy.attack_range_length, enemy.charge_duration)
	tween.tween_callback(_on_damage_frame)

## [内部逻辑] 伤害帧触发：执行闪烁特效，并在物理同步后进行伤害判定。
func _on_damage_frame() -> void:
	if not is_instance_valid(enemy): return

	# 1. 播放确认攻击的闪烁特效
	var flash_tween = create_safe_tween()
	flash_tween.tween_property(enemy.attack_visual, "color", Color(2.0, 2.0, 2.0, 1.0), 0.05)
	flash_tween.tween_property(enemy.attack_visual, "color", Color(1.0, 0.2, 0.2, 0.5), 0.05)
	
	# 2. 激活物理监测 (修复报错：确保获取重叠物体前开启 monitoring)
	enemy.attack_area.monitoring = true
	
	# 等待物理帧同步，确保 Area2D 刷新重叠列表
	await get_tree().physics_frame 
	await get_tree().physics_frame 
	
	if not is_instance_valid(enemy): return
	
	# 3. 判定伤害
	var bodies = enemy.attack_area.get_overlapping_bodies()
	for body in bodies:
		if body == enemy: continue
		if body is CharacterBase and body.character_type == CharacterBase.CharacterType.PLAYER:
			body.take_damage(enemy.attack_damage, enemy.character_type, enemy)
			var knock_dir = Vector2.RIGHT.rotated(enemy.attack_pivot.rotation)
			body.apply_knockback(knock_dir, 300.0)
	
	# 4. 关闭监测并结束攻击序列
	enemy.attack_area.set_deferred("monitoring", false)
	
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(enemy):
		enemy.attack_visual.visible = false
		is_attacking = false 
#endregion

#region 4. 状态转移

## [逻辑驱动] 检查转移条件：攻击结束后切回追击状态。
func _on_next_transitions() -> void:
	if not is_attacking:
		transition.emit("Chase") # 攻击完成，重回追击逻辑
#endregion
