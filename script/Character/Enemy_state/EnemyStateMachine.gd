@icon("res://Resource/Icon/FSMSprite.png")

class_name EnemyStateMachine
extends NodeStateMachine

## -------------------------------------------------------
## 敌人专用状态机
## 职责：继承通用状态机，额外增加“死亡中断”功能
## -------------------------------------------------------

func _ready() -> void:
	super._ready() # 必须调用父类初始化
	
	# 自动向上查找 Enemy 节点
	var enemy = get_parent() as Enemy
	
	if enemy:
		# [核心功能] 监听死亡信号
		# 一旦收到信号，无视当前在干什么，强制切到 Dead 状态
		enemy.on_dead.connect(_on_enemy_dead)

func _on_enemy_dead() -> void:
	print("状态机：检测到死亡，强制切换至 Dead")
	transition_to("Dead")
