@icon("res://Resource/Icon/StateSprite.png")
extends NodeState

@export var player: CharacterBody2D
@export var player_stats: CharacterBase
@export var animated_sprite_2d: AnimatedSprite2D

func _on_enter() -> void:
	if not player_stats or not player_stats.stats:
		transition.emit("Idle")
		return
	
	var stats = player_stats.stats as CharacterStatsComponent
	
	# [执行] 扣除耐力 + 触发冷却 + 获取速度
	if stats.check_and_consume_dash():
		animated_sprite_2d.play("Defense") # 播放冲刺/防御动画
		
		# 获取输入方向
		var input_dir = GameInputEvents.movement_input()
		# 获取朝向兜底 (假设 Scale.x > 0 向右)
		var facing_dir = Vector2.RIGHT if animated_sprite_2d.scale.x > 0 else Vector2.LEFT
		
		# 从 Stats 组件获取计算好的冲刺速度向量
		player.velocity = stats.calculate_dash_velocity(input_dir, facing_dir)
	else:
		# 理论上 Idle/Walk 已经检查过了，这里是双重保险
		transition.emit("Idle")

func _on_process(_delta: float) -> void:
	pass

func _on_physics_process(delta: float) -> void:
	# [执行] 移动
	player.move_and_slide()
	
	# [执行] 让 Stats 组件里的计时器走字
	if player_stats.stats:
		(player_stats.stats as CharacterStatsComponent).tick_dash_timer(delta)

func _on_next_transitions() -> void:
	var stats = player_stats.stats as CharacterStatsComponent
	
	# [决策] 询问组件：时间到了吗？
	if stats and stats.is_dash_finished():
		if GameInputEvents.is_movement_input():
			transition.emit("Walk")
		else:
			transition.emit("Idle")

func _on_exit() -> void:
	# [清理] 强制刹车，防止滑行
	player.velocity = Vector2.ZERO
	
	# [清理] 强制重置计时器 (防止被打断时残留时间)
	if player_stats and player_stats.stats:
		(player_stats.stats as CharacterStatsComponent).force_stop_dash_timer()
