extends Resource
class_name MapChoiceData

## 地图候选数据资源
## 职责：承载 ERS 保底地图选择界面的单张地图信息。

enum Rarity {
	B,
	A,
	S,
	SSR
}

@export var map_id: String = ""
@export var map_name: String = ""
@export var rarity: Rarity = Rarity.B
@export_multiline var description: String = ""

@export var satiety_cost: int = 10
@export var main_resources: Array[String] = []
@export var main_risks: Array[String] = []

@export var enemy_multiplier: float = 1.0
@export var resource_multiplier: float = 1.0
@export var food_multiplier: float = 1.0
@export var echo_multiplier: float = 1.0
@export var environment_decay_rate: float = 2.0

@export var possible_debuffs: Array[String] = []
@export var guaranteed_safe_choice: bool = false
