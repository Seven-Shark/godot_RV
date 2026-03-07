extends Resource
class_name CraftingRecipe

## 合成配方数据
## 定义如何合成一个物品

@export var result_item: ItemData ## 合成产出的物品
@export var result_count: int = 1 ## 产出数量

@export_group("Ingredients")
# 由于 Godot 导出字典不太方便，这里使用自定义资源数组或者简单的结构
# 为了简化，我们使用一个数组，每个元素是一个 Dictionary { "item": ItemData, "count": int }
# 但 Dictionary 在 Inspector 中不好编辑，所以我们用两个数组对应，或者定义一个小资源类。
# 为了方便编辑，这里我们定义一个内部类或者简单的数组对。

@export var ingredients: Array[IngredientStack] = []

## 制作所需时间 (秒)
@export var craft_time: float = 1.0 
