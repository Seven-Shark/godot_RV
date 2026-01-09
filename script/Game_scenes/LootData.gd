extends Resource
class_name LootData

## 掉落配置资源
## 用于定义一个物件可能会掉落什么物品

@export var item_scene: PackedScene ## 掉落物的场景文件 (tscn)
@export_range(0.0, 1.0) var drop_rate: float = 1.0 ## 爆率 (0.0 ~ 1.0)
@export var min_quantity: int = 1 ## 最小掉落数量
@export var max_quantity: int = 1 ## 最大掉落数量

# 获取该条目实际应该掉落的数量
func get_drop_count() -> int:
	# 1. 随机判断是否掉落
	if randf() > drop_rate:
		return 0
	
	# 2. 随机具体数量
	return randi_range(min_quantity, max_quantity)
