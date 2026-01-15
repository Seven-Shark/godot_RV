class_name ERS_CardData
extends Resource

@export var card_name: String = "未命名卡牌"
@export var icon: Texture2D ## 卡牌显示的图标
@export var object_prefab: PackedScene ## 对应的物件预制体
@export var price: int = 10 ## 购买价格
@export var description: String = "这就只是一个普通的物件。"
@export var spawn_weight: int = 10 ## 随机权重 (权重越高越容易随到)
