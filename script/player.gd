extends CharacterBase
class_name Player

var enter_Character : Array[CharacterBase] = []
var current_target : CharacterBase = null



func _init() -> void:
	character_type = CharacterType.PLAYER

func _ready() -> void:
	var playerAttack_Area = $DetectionArea
	playerAttack_Area.body_entered.connect(_on_playerAttack_Area_body_entered)
	playerAttack_Area.body_exited.connect(_on_playerAttack_Area_body_exited)

func _process(_delta):
	
	#根据移动方向改变图片朝向
	Turn()
	
	#寻找范围内最近的目标，并打印出来
	var nearest_target = get_closest_target()
	if nearest_target and nearest_target != current_target:
		print("找到最近的目标:",nearest_target.name)
		current_target = nearest_target
	elif not nearest_target and current_target:
		print("[目标丢失] 目标 ",current_target.name,"已离开或不再是最近目标。")
		current_target = null
		
	#朝向范围内最近的对象
	Target_Lock_On(nearest_target)


#region 角色攻击范围内识别对象的功能
	#1、先识别是否有物体进入区域
	#2、记录该物体是第几个进入区域的，并打上数字标签
	#3、对进入区域的物体进行识别和分类，并打上类型标签
	#4、判断当前距离我最近的物体
	#5、根据类型标签，执行应的方法
	#6、物体离开区域后，删除对应的信息，并让数字标签向前补位

#判断进入区域的是什么对象，并打上标签
func _on_playerAttack_Area_body_entered(body: Node2D):
	
	#判断是不是敌人
	if body is CharacterBase and body.character_type == CharacterType.ENEMY:
		var enemy_Character : CharacterBase = body
		#将敌人加入对象组
		enter_Character.append(enemy_Character)
		#打上进入标签
		var enter_ID = enter_Character.size()
		enemy_Character.set_target_tag(enter_ID)
		print(enemy_Character.name ,"进入区域" +"    "+"ID：" ,enemy_Character.current_tag)
		

#判断离开区域的是什么对象，并删除标签，同时重新对对象组行补位排序
func _on_playerAttack_Area_body_exited(body: Node2D):
	
	#判断是不是敌人
	if body is CharacterBase and body.character_type == CharacterType.ENEMY:
		var enemy_Character : CharacterBase = body
		
		#是的话找到他在数组中的位置，然后删除
		var index = enter_Character.find(enemy_Character)
		if index != -1:
			#移除
			enter_Character.remove_at(index)
			print(enemy_Character.name,"离开区域","    ","ID：",enemy_Character.current_tag )

#将对象组重新补位排序（未完成版，暂未用到）
func _updata_all_enter_Character():
	pass
	#for i in range(enter_Character.size())
	
	
#endregion
