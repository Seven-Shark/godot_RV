extends CanvasLayer
class_name GameHUD

## 游戏主界面 HUD (GameHUD)
## 职责：管理全局 UI 模块（金币、时间、ERS、背包等），并根据场景模式自动切换显示状态。

#region 1. 模式定义与节点引用
enum MapMode {
	HOME,       ## 家园模式
	SURVIVAL    ## 探险模式
}

@export_group("HUD Configuration")
@export var current_mode: MapMode = MapMode.HOME ## 在编辑器中设置当前场景模式

@export_group("UI Modules")
@export var shared_ui: Control ## 共用 UI 容器 (包含金币、ERS、背包)
@export var home_ui: Control ## 家园专有 UI 容器
@export var survival_ui: Control ## 探险专有 UI 容器

@export_group("Specific Elements")
@onready var gold_label: Label = $SharedUI/GoldLabel
@onready var day_cycle_ui: HBoxContainer = $SurvivalUI/DayCyclePanel/Background/HBoxContainer
@onready var ers_manager: ERS_Manager = $SharedUI/ERSLayer ## [核心引用] 供传送门或其他脚本调用
#endregion

#region 2. 生命周期
## [初始化] 配置模式显示并连接全局信号
func _ready() -> void:
	_apply_ui_mode()
	
	# 连接全局数据信号
	if Engine.has_singleton("GameDataManager") or get_node_or_null("/root/GameDataManager"):
		if not GameDataManager.gold_changed.is_connected(_on_gold_changed):
			GameDataManager.gold_changed.connect(_on_gold_changed)
		_on_gold_changed(GameDataManager.current_gold)

## [内部逻辑] 根据当前地图模式切换 UI 的可见性
func _apply_ui_mode() -> void:
	if shared_ui: shared_ui.visible = true
	
	match current_mode:
		MapMode.HOME:
			if home_ui: home_ui.visible = true
			if survival_ui: survival_ui.visible = false
		MapMode.SURVIVAL:
			if home_ui: home_ui.visible = false
			if survival_ui: survival_ui.visible = true
#endregion

#region 3. 业务接口 (由 Director/Portal 调用)

## [初始化] 接收导演配置并生成分段进度条 (仅探险模式)
func setup_day_cycle_ui(phases: Array[DayLoopConfig]) -> void:
	if current_mode == MapMode.SURVIVAL and day_cycle_ui and day_cycle_ui.has_method("setup_bars"):
		day_cycle_ui.setup_bars(phases)

## [每帧更新] 接收时间流逝并更新 UI 进度 (仅探险模式)
func update_time_display(phase_idx: int, remain: float, total: float) -> void:
	if current_mode == MapMode.SURVIVAL and day_cycle_ui and day_cycle_ui.has_method("update_progress"):
		day_cycle_ui.update_progress(phase_idx, remain, total)

## [接口] 暴露 ERS 开启方法 (方便外部统一通过 HUD 访问)
func open_ers(is_free: bool = false) -> void:
	if ers_manager and ers_manager.has_method("open_ers_shop"):
		ers_manager.open_ers_shop(is_free)
#endregion

#region 4. 信号回调
## [信号回调] 响应金币变化
func _on_gold_changed(new_amount: int) -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % new_amount
#endregion
