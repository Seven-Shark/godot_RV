extends CanvasLayer
class_name GameHUD

## 游戏主界面 HUD (GameHUD)
## 职责：管理全局 UI 模块（金币、时间、背包等），并根据场景模式自动切换显示状态。

#region 1. 模式定义与节点引用
enum MapMode {
	HOME,       ## 家园模式
	SURVIVAL    ## 探险模式
}

@export_group("HUD Configuration")
## 在编辑器中设置当前场景模式 (HOME 或 SURVIVAL)
@export var current_mode: MapMode = MapMode.HOME # 在编辑器中设置当前场景模式

@export_group("UI Modules")
## 共用 UI 容器 (包含金币、背包等常驻组件)
@export var shared_ui: Control # 共用 UI 容器
## 家园场景专有的 UI 容器
@export var home_ui: Control # 家园专有 UI 容器
## 探险场景专有的 UI 容器
@export var survival_ui: Control # 探险专有 UI 容器

@export_group("Specific Elements")
## 显示玩家金币数量的标签
@onready var gold_label: Label = $SharedUI/GoldLabel # 金币显示标签
## 探险模式下的昼夜循环进度 UI 容器
@onready var day_cycle_ui: HBoxContainer = $SurvivalUI/DayCyclePanel/Background/HBoxContainer # 昼夜循环面板
## 玩家饥饿度 UI 根面板
@onready var hunger_panel: Control = $SharedUI/HungerPanel # 饥饿度面板
## 饥饿度数值文本标签
@onready var hunger_label: Label = $SharedUI/HungerPanel/HungerLabel # 饥饿度标签
## 饥饿度进度条
@onready var hunger_bar: ProgressBar = $SharedUI/HungerPanel/HungerBar # 饥饿度进度条
## 噪音值显示根面板
@onready var noise_panel: Control = $SharedUI/NoisePanel # 噪音面板
## 噪音强度进度条
@onready var noise_bar: ProgressBar = $SharedUI/NoisePanel/NoiseBar # 噪音进度条
## ERS 保底地图选择界面
@onready var ers_map_selection_ui: ERSMapSelectionUI = $SharedUI/ERSMapSelectionUI # ERS 地图选择界面实例

var _player_stats: CharacterStatsComponent = null # 缓存玩家属性组件引用
var _shared_ui_visibility_cache: Dictionary = {} # ERS 打开前共享 HUD 的可见性缓存
## UI 噪音进度条显示的最大上限值
@export var noise_display_max_value: float = 100.0 # 噪音显示最大值
#endregion

#region 2. 生命周期逻辑
# 初始化 UI 状态，连接全局金币管理信号
func _ready() -> void:
	add_to_group("GameHUD")
	_apply_ui_mode()
	_bind_ers_ui_signals()
	
	# 连接全局数据信号
	if Engine.has_singleton("GameDataManager") or get_node_or_null("/root/GameDataManager"):
		if not GameDataManager.gold_changed.is_connected(_on_gold_changed):
			GameDataManager.gold_changed.connect(_on_gold_changed)
		_on_gold_changed(GameDataManager.current_gold)
	
	_try_bind_hunger_source()
	
	if hunger_panel:
		hunger_panel.visible = false
	if noise_panel:
		noise_panel.visible = false

# 每帧检查玩家引用，确保属性信号连接成功
func _process(_delta: float) -> void:
	if _player_stats == null:
		_try_bind_hunger_source()

# 根据当前 MapMode 切换不同场景对应的 UI 面板可见性
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

#region 3. 业务接口 (提供给 Director/Portal)
# 打开 ERS 保底地图选择界面
func open_ers_map_selection() -> bool:
	if not ers_map_selection_ui:
		return false
	ers_map_selection_ui.open_ui()
	return true

# 接收昼夜配置数据并初始化探险模式的时间 UI 布局
func setup_day_cycle_ui(phases: Array[DayLoopConfig]) -> void:
	if current_mode == MapMode.SURVIVAL and day_cycle_ui and day_cycle_ui.has_method("setup_bars"):
		day_cycle_ui.setup_bars(phases)

# 实时更新昼夜循环 UI 的各个阶段进度显示
func update_time_display(phase_idx: int, remain: float, total: float) -> void:
	if current_mode == MapMode.SURVIVAL and day_cycle_ui and day_cycle_ui.has_method("update_progress"):
		day_cycle_ui.update_progress(phase_idx, remain, total)

#endregion

#region 4. 内部数据绑定与信号回调
func _bind_ers_ui_signals() -> void:
	if not ers_map_selection_ui:
		return
	if not ers_map_selection_ui.ui_opened.is_connected(_on_ers_ui_opened):
		ers_map_selection_ui.ui_opened.connect(_on_ers_ui_opened)
	if not ers_map_selection_ui.ui_closed.is_connected(_on_ers_ui_closed):
		ers_map_selection_ui.ui_closed.connect(_on_ers_ui_closed)

func _on_ers_ui_opened() -> void:
	_set_character_hud_visible(false)

func _on_ers_ui_closed() -> void:
	_set_character_hud_visible(true)

func _set_character_hud_visible(visible: bool) -> void:
	if not shared_ui or not ers_map_selection_ui:
		return

	if not visible:
		_shared_ui_visibility_cache.clear()
		for child in shared_ui.get_children():
			if child == ers_map_selection_ui:
				continue
			if child is CanvasItem:
				_shared_ui_visibility_cache[child] = child.visible
				child.visible = false
		ers_map_selection_ui.visible = true
		return

	for child in _shared_ui_visibility_cache.keys():
		if child is CanvasItem:
			child.visible = bool(_shared_ui_visibility_cache[child])
	_shared_ui_visibility_cache.clear()

# 尝试从场景组获取玩家并绑定其属性组件信号
func _try_bind_hunger_source() -> void:
	var player = get_tree().get_first_node_in_group("Player") # 从 Group 中查找玩家
	if not player:
		return
	if not player.has_node("StatsComponent"):
		return
	var stats = player.get_node("StatsComponent") as CharacterStatsComponent # 强转属性组件
	if not stats:
		return
	
	_player_stats = stats
	
	# 连接饥饿度与噪音变化信号
	if not _player_stats.hunger_changed.is_connected(_on_hunger_changed):
		_player_stats.hunger_changed.connect(_on_hunger_changed)
	if not _player_stats.noise_changed.is_connected(_on_noise_changed):
		_player_stats.noise_changed.connect(_on_noise_changed)
	
	# 初始化 UI 数值
	_on_hunger_changed(_player_stats.current_hunger, _player_stats.max_hunger)
	_on_noise_changed(_player_stats.current_noise_value, _player_stats.current_noise_radius)

# 更新金币标签的显示内容
func _on_gold_changed(new_amount: int) -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % new_amount

# 响应饥饿度变化，实时更新进度条与百分比标签
func _on_hunger_changed(current: float, max_value: float) -> void:
	if not hunger_panel or not hunger_label or not hunger_bar:
		return
	hunger_panel.visible = true
	hunger_bar.max_value = max_value
	hunger_bar.value = current
	hunger_label.text = "饥饿 %.0f / %.0f" % [current, max_value]

# 响应噪音值变化，更新噪音计 UI 进度与具体数值
func _on_noise_changed(value: float, _radius: float) -> void:
	if not noise_panel or not noise_bar :
		return
	noise_panel.visible = true
	noise_bar.max_value = max(1.0, noise_display_max_value)
	noise_bar.value = clamp(value, 0.0, noise_bar.max_value)
#endregion
