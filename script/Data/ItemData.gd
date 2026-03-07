extends Resource
class_name ItemData

## 物品基础数据
## 用于定义游戏中所有的物品（资源、装备、建筑等）

enum ItemType {
	RESOURCE,   ## 基础资源 (木头、石头) - 不可建造，可合成
	BUILDABLE,  ## 建筑物件 (墙、塔) - 可建造
	CONSUMABLE, ## 消耗品 (药水)
	EQUIPMENT   ## 装备 (武器)
}

enum ItemQuality {
	COMMON,     ## 普通 (白)
	RARE,       ## 稀有 (蓝)
	EPIC,       ## 史诗 (紫)
	LEGENDARY   ## 传说 (橙)
}

@export_group("Basic Info")
@export var id: String = "" ## 物品唯一ID (如 "wood", "stone_wall")
@export var item_name: String = "New Item" ## 显示名称
@export_multiline var description: String = "" ## 物品描述
@export var icon: Texture2D ## 物品图标 (用于UI显示)
@export var quality: ItemQuality = ItemQuality.COMMON ## 物品品质

@export_group("Type & Behavior")
@export var item_type: ItemType = ItemType.RESOURCE ## 物品类型
@export var max_stack: int = 99 ## 最大堆叠数量

@export_group("Building (If Buildable)")
@export var build_prefab: PackedScene ## 如果是建筑，对应的预制体

func get_quality_color() -> Color:
	match quality:
		ItemQuality.COMMON: return Color.WHITE
		ItemQuality.RARE: return Color.CORNFLOWER_BLUE
		ItemQuality.EPIC: return Color.PURPLE
		ItemQuality.LEGENDARY: return Color.ORANGE
	return Color.WHITE
