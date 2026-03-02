extends CanvasLayer
class_name GameHUD

## 游戏主界面 HUD (GameHUD)
## 职责：显示玩家金币、昼夜循环进度等全局 UI 信息。
## 交互：被 GameDirector 调用以更新时间，监听 GameDataManager 更新金币。

#region 1. 节点引用
@onready var gold_label: Label = $GoldLabel
@onready var day_cycle_ui: HBoxContainer = $DayCyclePanel/Background/HBoxContainer
#endregion

#region 2. 生命周期
## [初始化] 连接全局数据信号并初始化基础 UI
func _ready() -> void:
	# 连接全局金币管理器的信号
	if Engine.has_singleton("GameDataManager") or get_node_or_null("/root/GameDataManager"):
		if not GameDataManager.gold_changed.is_connected(_on_gold_changed):
			GameDataManager.gold_changed.connect(_on_gold_changed)
			
		# 初始化显示当前金币
		_on_gold_changed(GameDataManager.current_gold)
#endregion

#region 3. 昼夜循环 UI 接口 (由 GameDirector 调用)

## [初始化] 接收导演的配置并生成对应的分段进度条
func setup_day_cycle_ui(phases: Array[DayLoopConfig]) -> void:
	if day_cycle_ui and day_cycle_ui.has_method("setup_bars"):
		day_cycle_ui.setup_bars(phases)

## [每帧更新] 接收导演的时间流逝并更新 UI 进度
func update_time_display(phase_idx: int, remain: float, total: float) -> void:
	if day_cycle_ui and day_cycle_ui.has_method("update_progress"):
		day_cycle_ui.update_progress(phase_idx, remain, total)

#endregion

#region 4. 信号回调

## [信号回调] 响应全局金币变化
func _on_gold_changed(new_amount: int) -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % new_amount

#endregion
