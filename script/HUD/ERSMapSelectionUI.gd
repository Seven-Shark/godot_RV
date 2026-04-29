extends Control
class_name ERSMapSelectionUI

## ERSMapSelectionUI.gd
## 职责：生成地图候选、处理地图选择与食物补给、并在确认后驱动进入下一日的探险流程。
## 逻辑：通过玩家当前的饱食度判定进入状态。若饱食度不足则会提示 Debuff 风险，支持强行进入。

signal ui_opened
signal ui_closed

#region 1. 场景引用与配置
@export_group("Scene References")
## 地图选项卡片的预制体场景
@export var map_card_scene: PackedScene # 地图选项卡片预制体

@export_group("Gameplay Config")
## 食物物品的 ID 标识
@export var food_item_id: String = "food" # 食物物品 ID
## 单个食物提供的饱食度恢复量
@export var food_heal_amount: int = 10 # 单个食物恢复量
#endregion

#region 2. 节点引用
@onready var day_label: Label = $Root/TopStatusBar/DayLabel # 顶部天数文本
@onready var satiety_bar: ProgressBar = $Root/TopStatusBar/SatietyBar # 饱食度进度条
@onready var satiety_label: Label = $Root/TopStatusBar/SatietyLabel # 饱食度数值文本
@onready var food_label: Label = $Root/TopStatusBar/FoodLabel # 顶部食物库存显示
@onready var echo_label: Label = $Root/TopStatusBar/EchoLabel # 顶部残响(金币)显示

@onready var map_card_container: HBoxContainer = $Root/MapCardContainer # 地图卡片容器

@onready var food_count_label: Label = $Root/BottomRow/FoodPanel/VBox/FoodCountLabel # 底部食物详情文本
@onready var eat_food_button: Button = $Root/BottomRow/FoodPanel/VBox/EatFoodButton # 进食按钮

@onready var selected_map_name_label: Label = $Root/BottomRow/SelectedMapPanel/VBox/SelectedMapNameLabel # 选中地图名称
@onready var required_satiety_label: Label = $Root/BottomRow/SelectedMapPanel/VBox/RequiredSatietyLabel # 消耗需求显示
@onready var current_satiety_label: Label = $Root/BottomRow/SelectedMapPanel/VBox/CurrentSatietyLabel # 当前饱食度对比显示
@onready var entry_status_label: Label = $Root/BottomRow/SelectedMapPanel/VBox/EntryStatusLabel # 进入状态描述
@onready var debuff_warning_label: Label = $Root/BottomRow/SelectedMapPanel/VBox/DebuffWarningLabel # 负面状态警告
@onready var reward_list_label: Label = $Root/BottomRow/SelectedMapPanel/VBox/RewardListLabel # 可能获得的资源列表
@onready var risk_list_label: Label = $Root/BottomRow/SelectedMapPanel/VBox/RiskListLabel # 风险列表
@onready var confirm_button: Button = $Root/BottomRow/SelectedMapPanel/VBox/ConfirmButton # 确认出发按钮

@onready var force_enter_dialog: ConfirmationDialog = $Root/ForceEnterDialog # 强行进入的二次确认弹窗
#endregion

#region 3. 内部状态变量
var _rng := RandomNumberGenerator.new() # 随机数生成器
var _map_pool: Array[MapChoiceData] = [] # 预置的地图资源池
var _map_choices: Array[MapChoiceData] = [] # 当前生成的候选地图
var _selected_map: MapChoiceData = null # 当前选中的地图数据
var _card_instances: Array[MapChoiceCard] = [] # 实例化的卡片节点缓存
var _cached_stats: CharacterStatsComponent = null # 缓存的玩家属性组件
#endregion

#region 4. 生命周期
# 初始化 UI 状态、随机数种子并构建默认地图池
func _ready() -> void:
	visible = false
	_rng.randomize()
	_map_pool = _build_default_map_pool()

	eat_food_button.pressed.connect(_on_eat_food_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	force_enter_dialog.confirmed.connect(_on_force_enter_confirmed)

#endregion

#region 5. UI 开关逻辑
# 开启地图选择界面，初始化玩家状态并生成候选
func open_ui() -> void:
	visible = true
	ui_opened.emit()
	_ensure_player_stats()
	_generate_map_choices()
	_refresh_all()

# 关闭地图选择界面
func close_ui() -> void:
	ui_closed.emit()
	visible = false

#endregion

#region 6. 地图生成与卡片管理
# 根据当前天数权重生成随机候选地图
func _generate_map_choices() -> void:
	_map_choices.clear()
	_selected_map = null

	# 保证至少有一个 B 级地图作为保底安全项
	var guaranteed_b := _get_random_map_by_rarity(MapChoiceData.Rarity.B)
	if guaranteed_b:
		_map_choices.append(guaranteed_b)

	while _map_choices.size() < 4:
		var rarity := _roll_rarity_by_day(GameManager.current_day)
		var choice := _get_random_map_by_rarity(rarity)
		if choice:
			_map_choices.append(choice)

	_map_choices.shuffle()
	_rebuild_map_cards()

# 清空旧卡片并根据生成的候选数据实例化新卡片
func _rebuild_map_cards() -> void:
	for child in map_card_container.get_children():
		child.queue_free()
	_card_instances.clear()

	for map_data in _map_choices:
		var card := map_card_scene.instantiate() as MapChoiceCard
		if not card:
			continue
		map_card_container.add_child(card)
		card.card_selected.connect(_on_map_card_selected)
		_card_instances.append(card)

#endregion

#region 7. UI 刷新逻辑
# 刷新界面所有子模块
func _refresh_all() -> void:
	_refresh_top_status()
	_refresh_food_panel()
	_refresh_cards()
	_refresh_selected_panel()

# 刷新顶部状态条（天数、饱食度、残响）
func _refresh_top_status() -> void:
	var current_satiety := _get_current_satiety()
	var max_satiety := _get_max_satiety()
	var safe_max_satiety: float = float(max_satiety if max_satiety > 0 else 1)
	var satiety_rate: float = float(current_satiety) / safe_max_satiety

	day_label.text = "第 %d 天 夜晚" % GameManager.current_day
	satiety_bar.max_value = max_satiety
	satiety_bar.value = current_satiety
	satiety_label.text = "饱食度：%d / %d" % [current_satiety, max_satiety]
	food_label.text = "食物：%d" % _get_food_count()
	echo_label.text = "残响：%d" % int(GameDataManager.current_gold)

	# 饱食度颜色视觉反馈
	if satiety_rate >= 0.7:
		satiety_label.modulate = Color(0.45, 1.0, 0.45)
	elif satiety_rate >= 0.3:
		satiety_label.modulate = Color(1.0, 0.9, 0.4)
	else:
		satiety_label.modulate = Color(1.0, 0.4, 0.4)

# 刷新底部食物信息面板
func _refresh_food_panel() -> void:
	food_count_label.text = "食物数量：%d (每个恢复 %d 饱食度)" % [_get_food_count(), food_heal_amount]

# 刷新所有候选卡片的选中状态
func _refresh_cards() -> void:
	var current_satiety := _get_current_satiety()
	for card in _card_instances:
		card.setup(card.map_data, current_satiety, card.map_data == _selected_map)

# 刷新选中地图后的详细信息及出发确认逻辑
func _refresh_selected_panel() -> void:
	if not _selected_map:
		selected_map_name_label.text = "选中地图：未选择"
		required_satiety_label.text = "饱食度需求：-"
		current_satiety_label.text = "当前饱食度：%d" % _get_current_satiety()
		entry_status_label.text = "状态：请选择地图"
		debuff_warning_label.text = ""
		reward_list_label.text = "可能获得：-"
		risk_list_label.text = "风险：-"
		confirm_button.disabled = true
		confirm_button.text = "请选择地图"
		return

	var current_satiety := _get_current_satiety()
	var debuff_count := _calculate_debuff_count(_selected_map.satiety_cost, current_satiety)
	var enough := debuff_count == 0

	selected_map_name_label.text = "选中地图：%s级 %s" % [_rarity_text(_selected_map.rarity), _selected_map.map_name]
	required_satiety_label.text = "饱食度需求：%d" % _selected_map.satiety_cost
	current_satiety_label.text = "当前饱食度：%d" % current_satiety
	entry_status_label.text = "状态：正常进入" if enough else "状态：强行进入"
	debuff_warning_label.text = "Debuff：无" if enough else "警告：饱食度不足，预计 Debuff %d 个" % debuff_count
	debuff_warning_label.modulate = Color(1, 1, 1) if enough else Color(1.0, 0.35, 0.35)
	reward_list_label.text = "可能获得：\n- " + "\n- ".join(_selected_map.main_resources)
	risk_list_label.text = "风险：\n- " + "\n- ".join(_selected_map.main_risks)
	confirm_button.disabled = false
	confirm_button.text = "确认明日地图" if enough else "强行进入"

#endregion

#region 8. 交互事件处理
# 处理地图卡片选中事件
func _on_map_card_selected(card: MapChoiceCard) -> void:
	_selected_map = card.map_data
	_refresh_cards()
	_refresh_selected_panel()

# 处理进食按钮按下事件，恢复玩家饱食度
func _on_eat_food_pressed() -> void:
	_ensure_player_stats()
	if _get_food_count() <= 0:
		return
	if _get_current_satiety() >= _get_max_satiety():
		return
	if not GameDataManager.remove_item(food_item_id, 1):
		return
	if _cached_stats:
		_cached_stats.current_hunger = min(_cached_stats.max_hunger, _cached_stats.current_hunger + food_heal_amount)
		_cached_stats.hunger_changed.emit(_cached_stats.current_hunger, _cached_stats.max_hunger)
	_refresh_all()

# 处理确认出发按钮按下事件
func _on_confirm_pressed() -> void:
	if not _selected_map:
		return
	var debuff_count := _calculate_debuff_count(_selected_map.satiety_cost, _get_current_satiety())
	if debuff_count > 0:
		force_enter_dialog.dialog_text = "饱食度不足\n\n该地图需要 %d 饱食度。\n你当前只有 %d 饱食度。\n\n强行进入后，明天会获得 %d 个负面 Debuff。\n\n是否仍然进入？" % [_selected_map.satiety_cost, _get_current_satiety(), debuff_count]
		force_enter_dialog.popup_centered()
		return
	_enter_next_day(0)

# 处理强行进入对话框确认事件
func _on_force_enter_confirmed() -> void:
	if not _selected_map:
		return
	var debuff_count := _calculate_debuff_count(_selected_map.satiety_cost, _get_current_satiety())
	_enter_next_day(debuff_count)

# 执行天数转换，扣除饱食度并加载新地图场景
func _enter_next_day(debuff_count: int) -> void:
	_ensure_player_stats()
	var satiety_to_cost := _selected_map.satiety_cost
	if _cached_stats:
		_cached_stats.current_hunger = max(0.0, _cached_stats.current_hunger - satiety_to_cost)
		_cached_stats.hunger_changed.emit(_cached_stats.current_hunger, _cached_stats.max_hunger)

	GameManager.pending_map_choice_data = _map_data_to_dict(_selected_map)
	GameManager.pending_debuff_count = debuff_count
	GameManager.current_map_decay_rate = _selected_map.environment_decay_rate

	close_ui()
	GameManager.goto_survival_scene([], _selected_map.environment_decay_rate)

#endregion

#region 9. 数据获取与计算辅助
# 确保获取到玩家的 StatsComponent 引用
func _ensure_player_stats() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		_cached_stats = null
		return
	if not player.has_node("StatsComponent"):
		_cached_stats = null
		return
	_cached_stats = player.get_node("StatsComponent") as CharacterStatsComponent

# 获取当前饱食度数值
func _get_current_satiety() -> int:
	_ensure_player_stats()
	if not _cached_stats:
		return 0
	return int(_cached_stats.current_hunger)

# 获取最大饱食度上限
func _get_max_satiety() -> int:
	_ensure_player_stats()
	if not _cached_stats:
		return 100
	return int(_cached_stats.max_hunger)

# 从数据管理器中获取食物库存数量
func _get_food_count() -> int:
	return GameDataManager.get_item_count(food_item_id)

# 根据饱食度缺口计算获得的 Debuff 数量
func _calculate_debuff_count(required_satiety: int, current_satiety: int) -> int:
	var gap := required_satiety - current_satiety
	if gap <= 0:
		return 0
	if gap <= 10:
		return 1
	if gap <= 25:
		return 2
	return 3

# 根据生存天数计算抽取的稀有度概率表
func _roll_rarity_by_day(day: int) -> int:
	var table: Dictionary
	if day <= 3:
		table = {
			MapChoiceData.Rarity.B: 70,
			MapChoiceData.Rarity.A: 30,
			MapChoiceData.Rarity.S: 0,
			MapChoiceData.Rarity.SSR: 0
		}
	elif day <= 7:
		table = {
			MapChoiceData.Rarity.B: 50,
			MapChoiceData.Rarity.A: 35,
			MapChoiceData.Rarity.S: 15,
			MapChoiceData.Rarity.SSR: 0
		}
	elif day <= 12:
		table = {
			MapChoiceData.Rarity.B: 35,
			MapChoiceData.Rarity.A: 40,
			MapChoiceData.Rarity.S: 20,
			MapChoiceData.Rarity.SSR: 5
		}
	else:
		table = {
			MapChoiceData.Rarity.B: 25,
			MapChoiceData.Rarity.A: 40,
			MapChoiceData.Rarity.S: 25,
			MapChoiceData.Rarity.SSR: 10
		}

	var roll := _rng.randi_range(1, 100)
	var cumulative := 0
	for rarity in [MapChoiceData.Rarity.B, MapChoiceData.Rarity.A, MapChoiceData.Rarity.S, MapChoiceData.Rarity.SSR]:
		cumulative += int(table[rarity])
		if roll <= cumulative:
			return rarity
	return MapChoiceData.Rarity.B

# 从地图池中随机获取对应稀有度的地图数据
func _get_random_map_by_rarity(rarity: int) -> MapChoiceData:
	var candidates: Array[MapChoiceData] = []
	for data in _map_pool:
		if data.rarity == rarity:
			candidates.append(data)
	if candidates.is_empty():
		return null
	return candidates[_rng.randi_range(0, candidates.size() - 1)]

# 将 Resource 数据转换为字典形式以便跨场景传递
func _map_data_to_dict(data: MapChoiceData) -> Dictionary:
	return {
		"map_id": data.map_id,
		"map_name": data.map_name,
		"rarity": _rarity_text(data.rarity),
		"satiety_cost": data.satiety_cost,
		"main_resources": data.main_resources.duplicate(),
		"main_risks": data.main_risks.duplicate(),
		"enemy_multiplier": data.enemy_multiplier,
		"resource_multiplier": data.resource_multiplier,
		"food_multiplier": data.food_multiplier,
		"echo_multiplier": data.echo_multiplier,
		"environment_decay_rate": data.environment_decay_rate
	}

# 辅助方法：返回稀有度的文本标识
func _rarity_text(rarity: int) -> String:
	match rarity:
		MapChoiceData.Rarity.B: return "B"
		MapChoiceData.Rarity.A: return "A"
		MapChoiceData.Rarity.S: return "S"
		MapChoiceData.Rarity.SSR: return "SSR"
		_: return "B"

#endregion

#region 10. 资源池构建
# 构建内置的默认地图池数据
func _build_default_map_pool() -> Array[MapChoiceData]:
	var result: Array[MapChoiceData] = []

	var b1 := MapChoiceData.new()
	b1.map_id = "wet_forest_b"
	b1.map_name = "潮湿森林"
	b1.rarity = MapChoiceData.Rarity.B
	b1.satiety_cost = 12
	b1.main_resources = ["木头", "食物"]
	b1.main_risks = ["敌人密度中等"]
	b1.environment_decay_rate = 1.5
	b1.guaranteed_safe_choice = true
	result.append(b1)

	var b2 := MapChoiceData.new()
	b2.map_id = "stone_field_b"
	b2.map_name = "碎石荒地"
	b2.rarity = MapChoiceData.Rarity.B
	b2.satiety_cost = 10
	b2.main_resources = ["石头", "木头"]
	b2.main_risks = ["夜晚能见度较差"]
	b2.environment_decay_rate = 1.8
	b2.guaranteed_safe_choice = true
	result.append(b2)

	var a1 := MapChoiceData.new()
	a1.map_id = "echo_tower_a"
	a1.map_name = "回波塔外围"
	a1.rarity = MapChoiceData.Rarity.A
	a1.satiety_cost = 20
	a1.main_resources = ["残响", "石头"]
	a1.main_risks = ["听觉者增多", "黄昏后更活跃"]
	a1.environment_decay_rate = 2.2
	result.append(a1)

	var a2 := MapChoiceData.new()
	a2.map_id = "wood_canyon_a"
	a2.map_name = "林木峡谷"
	a2.rarity = MapChoiceData.Rarity.A
	a2.satiety_cost = 18
	a2.main_resources = ["木头", "食物"]
	a2.main_risks = ["地形狭窄", "夹击概率上升"]
	a2.environment_decay_rate = 2.0
	result.append(a2)

	var s1 := MapChoiceData.new()
	s1.map_id = "night_marsh_s"
	s1.map_name = "夜沼断层"
	s1.rarity = MapChoiceData.Rarity.S
	s1.satiety_cost = 30
	s1.main_resources = ["残响", "稀有材料"]
	s1.main_risks = ["环境侵蚀提升", "敌人数量显著增加"]
	s1.environment_decay_rate = 3.0
	result.append(s1)

	var s2 := MapChoiceData.new()
	s2.map_id = "ruin_depth_s"
	s2.map_name = "遗迹深层"
	s2.rarity = MapChoiceData.Rarity.S
	s2.satiety_cost = 28
	s2.main_resources = ["石头", "残响"]
	s2.main_risks = ["夜晚强化敌人", "刷新点更危险"]
	s2.environment_decay_rate = 2.8
	result.append(s2)

	var ssr1 := MapChoiceData.new()
	ssr1.map_id = "golden_relic_ssr"
	ssr1.map_name = "金辉遗迹"
	ssr1.rarity = MapChoiceData.Rarity.SSR
	ssr1.satiety_cost = 36
	ssr1.main_resources = ["高额残响", "稀有事件"]
	ssr1.main_risks = ["高压战斗", "多重环境惩罚"]
	ssr1.environment_decay_rate = 3.5
	result.append(ssr1)

	return result
#endregion
