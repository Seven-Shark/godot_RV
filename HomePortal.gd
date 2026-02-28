extends Area2D

## 家园传送门 (HomePortal)
## 职责：检测玩家靠近，按E打开家园里的 ERS 界面。

#region 1. 引用配置
@export var ers_manager: ERS_Manager ## 在检查器里把家园里的 ERS 实例拖进来
#endregion

#region 2. 状态变量
var is_player_in_range: bool = false ## 玩家是否在传送门范围内
#endregion

#region 3. 生命周期与交互
func _ready() -> void:
	# 连接进入/离开信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 连接 ERS 的确认信号
	if ers_manager:
		ers_manager.items_confirmed.connect(_on_ers_items_confirmed)

func _input(event: InputEvent) -> void:
	# 玩家在范围内按 E 键（假设你配置了 interact 动作）
	if is_player_in_range and event.is_action_pressed("interact"):
		if ers_manager:
			ers_manager.open_ers_shop(true) # 以“家园模式”打开

## [信号回调] 玩家选完物品点击出发
func _on_ers_items_confirmed(items: Array[PackedScene]) -> void:
	# 呼叫大管家，带上东西去探险！
	GameManager.goto_survival_scene(items)
#endregion

#region 4. 范围检测
func _on_body_entered(body: Node) -> void:
	if body is CharacterBase: # 替换为你玩家的类名
		is_player_in_range = true
		print(">>> 提示：按 E 开启传送门")

func _on_body_exited(body: Node) -> void:
	if body is CharacterBase:
		is_player_in_range = false
#endregion
