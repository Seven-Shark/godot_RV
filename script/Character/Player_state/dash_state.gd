@icon("res://Resource/Icon/StateSprite.png")
extends NodeState

@export var player:CharacterBody2D
@export var animated_Sprite_2d:AnimatedSprite2D
@export var dash_Speed:float = 1000.0
@export var dashCD:float = 0.1
@export var dashTime:float = 0.2

#@export var dash_max:float = 200.0

func _on_enter() -> void:
	animated_Sprite_2d.play("Defense")

func _on_process(_delta : float) -> void:
	pass

func _on_physics_process(_delta : float) -> void:
	
	GameInputEvents.canDash = false
	#获取玩家输入，确认角色的朝向，并且将当前速度归零
	if GameInputEvents.canDash == false && GameInputEvents.is_dash_input() == true:
		var direction = GameInputEvents.movement_input()
		player.velocity = Vector2.ZERO 

	#通过获取方向后赋予冲刺速度，并且等待冲刺时间结束后停止
		var dash_direction = direction.normalized()
		player.velocity = dash_direction * dash_Speed
		player.move_and_slide()
		await get_tree().create_timer(dashTime).timeout
		GameInputEvents.isDashing = false
		await get_tree().create_timer(dashCD).timeout
		GameInputEvents.canDash = true

func _on_next_transitions() -> void:
	
	if GameInputEvents.is_dash_input() == false:
		if GameInputEvents.movement_input() != Vector2.ZERO:
			transition.emit("Walk")
		else:
			transition.emit("Idle")

func _on_exit() -> void:
	pass



	#通过获取方向后赋予冲刺速度，并且等待冲刺距离达到最大距离后停止冲刺
	#if GameInputEvents.is_dash_input():
		#var dash_direction = direction.normalized()
		#player.velocity = dash_direction * dash_speed
		#player.move_and_slide()
		#print(player.velocity)
		#var distance_traveled:float = 0
		#while distance_traveled < dash_max:
			#distance_traveled += player.velocity.length() * _delta
			#print(distance_traveled)
			#await get_tree().create_timer(0.01).timeout
		#player.velocity = Vector2.ZERO
	#GameInputEvents.is_dash = false
	
	

	
