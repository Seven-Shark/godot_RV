extends Node2D


@onready var anim = $AnimationPlayer
@onready var hitbox: Area2D = $Weapon_Hitbox
@export var damage_amount : int = 10 # 定义伤害值

func _ready():
	# 连接 Area2D 的 body_entered 信号
	hitbox.body_entered.connect(_on_hitbox_body_entered)

func play_idle():
	anim.play("Axe_Idle")
	
func play_attack():
	anim.play("Axe_Attack")

func _on_hitbox_body_entered(body: Node2D):
	if body.is_in_group("Enemy") and body.has_method("take_damage"):
		print("命中敌人：", body.name)
		body.take_damage(damage_amount)
