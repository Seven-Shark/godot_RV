extends Node2D


@onready var anim = $AnimationPlayer
@onready var hitbox: Area2D = $Weapon_Hitbox
@export var damage_amount : int = 10 # 定义伤害值

#定义武器的归属者是谁
var belonger:CharacterBase


func _ready():
	print("Axe Hitbox 节点是: ", hitbox) # 确保这里打印出来的不是 null
	print("Hitbox Monitoring 状态: ", hitbox.monitoring) # 确保这里打印的是 true
	# 连接 Area2D 的 body_entered 信号
	hitbox.body_entered.connect(_on_hitbox_body_entered)


func play_idle():
	anim.play("Axe_Idle")
	
func play_attack():
	anim.play("Axe_Attack")

func _on_hitbox_body_entered(body: Node2D):
	
	print("【调试】斧头撞到了：", body.name, " 类型：", body.get_class())
	#确保有所有者
	#if not belonger or not(body is CharacterBase):
		#return
	if body == belonger:
		return
	#调用对方的 take_damage，并传入持有者的类型
	if body.has_method("take_damage"):
		print(name + "攻击命中:",body.name)
		body.take_damage(damage_amount,belonger.character_type,belonger)
	#确保打到的是characterbase
	#if body is CharacterBase :
		#排除自己，防止自残


	
