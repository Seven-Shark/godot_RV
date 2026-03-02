extends Resource
class_name BuildingRecipe

## 建筑配方数据
@export var building_name: String = "未命名建筑"
@export var icon: Texture2D ## 背包中显示的图标
@export var ghost_texture: Texture2D ## 建造虚影的贴图
@export var prefab: PackedScene ## 真正生成的建筑实体预制体

@export_group("Placement Settings")
@export var build_distance: float = 80.0 ## 距离玩家身前的生成距离
@export var collision_size: Vector2 = Vector2(32, 32) ## 虚影碰撞盒大小 (用于检测是否能放置)

@export_group("Cost")
@export var cost_wood: int = 0
@export var cost_stone: int = 0
# 可以根据你的资源系统继续扩展
