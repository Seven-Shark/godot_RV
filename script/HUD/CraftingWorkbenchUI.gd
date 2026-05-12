extends Control
class_name CraftingWorkbenchUI

## 通用合成台界面
## 职责：独立承载装备合成、地图合成的通用台面、背包格子、分类页签、悬浮说明与合成接口。

signal craft_requested(base_item: Dictionary, material_items: Array)
signal workbench_changed(base_item: Dictionary, material_items: Array)
signal item_added_to_table(item_data: Dictionary)
signal item_removed_from_table(item_data: Dictionary)

#region 1. 暴露的配置参数
@export_group("Debug")
@export var use_config_items: bool = true ## 是否从 CSV 配置读取背包展示数据

@export_group("Workbench")
@export var max_material_slots: int = 9 ## 台面材料槽位数量
@export var slot_size: Vector2 = Vector2(72, 72) ## 背包与台面槽位尺寸
@export var tooltip_max_size: Vector2 = Vector2(360, 260) ## 悬浮说明最大尺寸

var base_filter: Callable ## 外部基底筛选接口
var material_filter: Callable ## 外部材料筛选接口
var result_preview_provider: Callable ## 外部结果预览接口
var craft_handler: Callable ## 外部合成执行接口
#endregion

#region 2. 内部状态数据
const TEXT := {
	"title": "通用合成台",
	"prep_title": "营地准备",
	"base_empty": "选择基底",
	"material_empty": "材料槽",
	"result_title": "成品属性",
	"blueprint_title": "合成列表",
	"result_empty": "请先选择基底和材料",
	"blueprint_empty": "暂无可合成蓝图",
	"craft": "合成",
	"all": "全部",
	"equipment": "装备",
	"map": "地图",
	"material": "材料",
	"food": "食物",
	"status_select_base": "请先从背包选择一个可作为基底的物品。",
	"status_select_material": "已选择基底，继续选择材料。",
	"status_ready": "条件满足，可以合成。",
	"status_crafted": "合成完成，成品保留在基底槽。",
	"status_need_material": "至少需要 1 个材料才能合成。",
	"status_no_slot": "材料槽已满。",
	"status_invalid_base": "该物品不能作为基底。",
	"status_invalid_material": "该物品不能作为当前基底的材料。",
	"status_no_socket": "当前基底没有可用镶嵌槽。",
	"status_no_upgrade": "背包中没有同名同品质基底，无法升级。",
	"status_upgraded": "基底升级完成。",
	"status_upgrade_missing": "需要消耗%s，当前无可用材料",
	"shop": "购买地图元素",
	"prep_tab": "准备界面",
	"craft_tab": "合成界面",
	"shop_tab": "商店界面",
	"back_to_craft": "前往合成表",
	"shop_title": "地图元素卡包",
	"gold": "金币：%d",
	"pack_stock": "剩余：%d",
	"pack_price": "价格：%d",
	"pack_sold_out": "已售空",
	"pack_detail_unknown": "%s + %s",
	"open_pack_title": "获得地图元素",
	"open_pack_close": "点击任意位置关闭界面",
	"socket_empty": "空镶嵌槽",
	"upgrade": "升级",
	"remove_material_title": "卸下镶嵌材料？",
	"upgrade_title": "选择升级消耗材料",
	"previewing": "预览中",
	"character_info": "角色数值",
	"map_info": "明日地图",
	"character_empty": "角色",
	"map_empty": "选择明日地图",
	"next_day": "前往下一天",
	"next_day_ready": "下一天入口已准备，后续接入回合流程。",
	"hunger": "饱食度：%d/%d",
	"hunger_full": "饱食度已满，无法食用。",
	"map_hunger_need": "入场饱食度：%d",
	"map_hunger_warning": "饱食度不足，将获得 Debuff：%s",
	"next_day_hunger_title": "饱食度不足",
	"next_day_hunger_confirm": "当前饱食度不足，进入地图会面临 Debuff：%s\n是否继续？",
	"eat": "食用",
	"sort_inventory": "整理",
	"slot_helmet": "头盔",
	"slot_armor": "护甲",
	"slot_pants": "裤子",
	"slot_shoes": "鞋子",
	"slot_weapon": "武器",
	"slot_accessory": "饰品",
	"slot_tool_1": "道具1",
	"slot_tool_2": "道具2",
	"confirm": "确认",
	"cancel": "取消"
}

const CATEGORY_ALL := "all"
const CATEGORY_EQUIPMENT := "equipment"
const CATEGORY_MAP := "map"
const CATEGORY_MATERIAL := "material"
const CATEGORY_FOOD := "food"
const MODE_PREP := "prep"
const MODE_CRAFT := "craft"
const MODE_SHOP := "shop"
const MODE_BUILD := "build"
const BUILD_TAB_BUILT := "built"
const BUILD_TAB_UNBUILT := "unbuilt"
const FACILITY_TYPE_WORK := "work"
const FACILITY_TYPE_ENHANCE := "enhance"
const PREP_EQUIP_SLOTS := ["helmet", "armor", "pants", "shoes", "weapon", "accessory", "tool_1", "tool_2"]
const MAP_BASE_CATEGORY := "map_base"
const MAP_PACK_ORDER := ["map_base", "terrain", "water", "site", "plant", "mineral", "food", "creature", "hazard"]
const MAP_CATEGORY_NAMES := {
	"map_base": "地图环境包",
	"terrain": "地形卡包",
	"water": "水域卡包",
	"site": "地点卡包",
	"plant": "植物卡包",
	"mineral": "矿物卡包",
	"food": "食物卡包",
	"creature": "生物卡包",
	"hazard": "危险卡包"
}
const PACK_QUALITY_WEIGHT := {
	"common": 100,
	"rare": 35,
	"epic": 12,
	"legendary": 4
}
const PACK_DRAW_COUNT := 3
const DEFAULT_START_GOLD := 100
const DEFAULT_PACK_STOCK := 4
const DEFAULT_PACK_PRICE := 10
const FLIP_CARD_COLS := 3
const FLIP_BASE_PRICE := 10
const FLIP_REFRESH_BASE_PRICE := 15
const FLIP_DELETE_TOOL_START_COUNT := 2
const FLIP_UPGRADE_TOOL_START_COUNT := 2
const DEFAULT_MAX_HUNGER := 100
const DEFAULT_START_HUNGER := 70
const DEFAULT_MAP_HUNGER_COST := 30
const DEFAULT_MAP_HUNGER_DEBUFF := "饥饿：探索时体力恢复降低"
const INVENTORY_CATEGORY_SORT := {
	CATEGORY_EQUIPMENT: 10,
	CATEGORY_MAP: 20,
	CATEGORY_MATERIAL: 30,
	CATEGORY_FOOD: 40
}
const INVENTORY_QUALITY_SORT := {
	"legendary": 1,
	"epic": 2,
	"rare": 3,
	"common": 4
}
const PACK_TOOLTIP_MAX_SIZE := Vector2(460, 900)
const CARD_TOOL_NONE := ""
const CARD_TOOL_DELETE := "delete"
const CARD_TOOL_UPGRADE := "upgrade"
const FLIP_ROW_MAP := "map"
const FLIP_ROW_RESOURCE := "resource"
const FLIP_ROW_CHANCE := "chance"
const FLIP_ROW_GOD := "god"
const FLIP_CARD_ROWS := [FLIP_ROW_MAP, FLIP_ROW_RESOURCE, FLIP_ROW_CHANCE, FLIP_ROW_GOD]
const FLIP_ROW_NAMES := {
	FLIP_ROW_MAP: "地图牌",
	FLIP_ROW_RESOURCE: "资源牌",
	FLIP_ROW_CHANCE: "机遇牌",
	FLIP_ROW_GOD: "天神牌"
}
const FLIP_ROW_SOURCE_CATEGORIES := {
	FLIP_ROW_MAP: ["map_base"],
	FLIP_ROW_RESOURCE: ["terrain", "water", "plant", "mineral", "food", "creature", "hazard"],
	FLIP_ROW_CHANCE: ["site", "hazard"],
	FLIP_ROW_GOD: ["god"]
}
const FLIP_QUALITY_UPGRADE := {
	"common": "rare",
	"rare": "epic",
	"epic": "legendary",
	"legendary": "legendary"
}
const TOOLTIP_MIN_SIZE := Vector2(180, 96)
const TOOLTIP_PADDING_SIZE := Vector2(36, 42)
const TOOLTIP_DESC_MAX_LENGTH := 52
const TOOLTIP_PROPS_MAX_LENGTH := 80
const MAP_ELEMENTS_CSV_PATH := "res://script/Data/CSVs/MapElements.txt"

@onready var main_panel: PanelContainer = $Root/MainPanel
@onready var prep_tab_button: Button = $Root/MainPanel/MainLayout/HeaderBar/ScreenTabBar/PrepTabButton
@onready var craft_tab_button: Button = $Root/MainPanel/MainLayout/HeaderBar/ScreenTabBar/CraftTabButton
@onready var shop_tab_button: Button = $Root/MainPanel/MainLayout/HeaderBar/ScreenTabBar/ShopTabButton
@onready var screen_tab_bar: HBoxContainer = $Root/MainPanel/MainLayout/HeaderBar/ScreenTabBar
@onready var craft_content: HBoxContainer = $Root/MainPanel/MainLayout/CraftContent
@onready var title_label: Label = $Root/MainPanel/MainLayout/HeaderBar/TitleLabel
@onready var gold_label: Label = $Root/MainPanel/MainLayout/HeaderBar/GoldLabel
@onready var prep_info_panel: VBoxContainer = $Root/MainPanel/MainLayout/CraftContent/PrepInfoPanel
@onready var character_info_panel: PanelContainer = $Root/MainPanel/MainLayout/CraftContent/PrepInfoPanel/CharacterInfoPanel
@onready var character_info_list: VBoxContainer = $Root/MainPanel/MainLayout/CraftContent/PrepInfoPanel/CharacterInfoPanel/CharacterInfoScroll/CharacterInfoList
@onready var map_info_panel: PanelContainer = $Root/MainPanel/MainLayout/CraftContent/PrepInfoPanel/MapInfoPanel
@onready var map_info_list: VBoxContainer = $Root/MainPanel/MainLayout/CraftContent/PrepInfoPanel/MapInfoPanel/MapInfoScroll/MapInfoList
@onready var prep_panel: PanelContainer = $Root/MainPanel/MainLayout/CraftContent/PrepPanel
@onready var character_loadout_panel: PanelContainer = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/CharacterLoadoutPanel
@onready var character_visual_slot: Button = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/CharacterLoadoutPanel/CharacterLoadoutLayout/CharacterCenter/CharacterCenterLayout/CharacterVisualSlot
@onready var hunger_label: Label = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/CharacterLoadoutPanel/CharacterLoadoutLayout/CharacterCenter/CharacterCenterLayout/HungerLabel
@onready var hunger_bar: ProgressBar = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/CharacterLoadoutPanel/CharacterLoadoutLayout/CharacterCenter/CharacterCenterLayout/HungerBar
@onready var prep_gold_label: Label = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/CharacterLoadoutPanel/CharacterLoadoutLayout/CharacterCenter/CharacterCenterLayout/PrepGoldLabel
@onready var map_prep_panel: PanelContainer = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/MapPrepPanel
@onready var prep_map_slot: Button = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/MapPrepPanel/MapPrepLayout/PrepMapSlot
@onready var map_warning_label: Label = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/MapPrepPanel/MapPrepLayout/MapWarningLabel
@onready var next_day_button: Button = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/MapPrepPanel/MapPrepLayout/NextDayButton
@onready var helmet_slot: Button = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/CharacterLoadoutPanel/CharacterLoadoutLayout/LeftEquipSlots/HelmetSlot
@onready var armor_slot: Button = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/CharacterLoadoutPanel/CharacterLoadoutLayout/LeftEquipSlots/ArmorSlot
@onready var pants_slot: Button = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/CharacterLoadoutPanel/CharacterLoadoutLayout/LeftEquipSlots/PantsSlot
@onready var shoes_slot: Button = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/CharacterLoadoutPanel/CharacterLoadoutLayout/LeftEquipSlots/ShoesSlot
@onready var weapon_slot: Button = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/CharacterLoadoutPanel/CharacterLoadoutLayout/RightEquipSlots/WeaponSlot
@onready var accessory_slot: Button = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/CharacterLoadoutPanel/CharacterLoadoutLayout/RightEquipSlots/AccessorySlot
@onready var tool_1_slot: Button = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/CharacterLoadoutPanel/CharacterLoadoutLayout/RightEquipSlots/Tool1Slot
@onready var tool_2_slot: Button = $Root/MainPanel/MainLayout/CraftContent/PrepPanel/PrepLayout/CharacterLoadoutPanel/CharacterLoadoutLayout/RightEquipSlots/Tool2Slot
@onready var workbench_panel: PanelContainer = $Root/MainPanel/MainLayout/CraftContent/WorkbenchPanel
@onready var base_slot: Button = $Root/MainPanel/MainLayout/CraftContent/WorkbenchPanel/WorkbenchLayout/BasePanel/BaseSlotRow/BaseSlot
@onready var upgrade_button: Button = $Root/MainPanel/MainLayout/CraftContent/WorkbenchPanel/WorkbenchLayout/BasePanel/BaseSlotRow/UpgradeButton
@onready var base_result_panel: PanelContainer = $Root/MainPanel/MainLayout/CraftContent/WorkbenchPanel/WorkbenchLayout/BasePanel/BaseSlotRow/BaseResultPanel
@onready var base_result_list: VBoxContainer = $Root/MainPanel/MainLayout/CraftContent/WorkbenchPanel/WorkbenchLayout/BasePanel/BaseSlotRow/BaseResultPanel/BaseResultLayout/BaseResultScroll/BaseResultList
@onready var material_grid: GridContainer = $Root/MainPanel/MainLayout/CraftContent/WorkbenchPanel/WorkbenchLayout/MaterialPanel/MaterialGrid
@onready var result_panel: PanelContainer = $Root/MainPanel/MainLayout/CraftContent/ResultPanel
@onready var result_title: Label = $Root/MainPanel/MainLayout/CraftContent/ResultPanel/ResultLayout/ResultTitle
@onready var result_list: VBoxContainer = $Root/MainPanel/MainLayout/CraftContent/ResultPanel/ResultLayout/ResultScroll/ResultList
@onready var store_panel: PanelContainer = $Root/MainPanel/MainLayout/CraftContent/StorePanel
@onready var store_title: Label = $Root/MainPanel/MainLayout/CraftContent/StorePanel/StoreLayout/StoreHeader/StoreTitle
@onready var shop_gold_label: Label = $Root/MainPanel/MainLayout/CraftContent/StorePanel/StoreLayout/StoreHeader/ShopGoldLabel
@onready var card_rows_container: VBoxContainer = $Root/MainPanel/MainLayout/CraftContent/StorePanel/StoreLayout/CardRowsScroll/CardRows
@onready var flip_start_next_day_button: Button = $Root/MainPanel/MainLayout/CraftContent/StorePanel/StoreLayout/StoreActionBar/StartNextDayButton
@onready var delete_tool_button: Button = $Root/MainPanel/MainLayout/CraftContent/StorePanel/StoreLayout/StoreActionBar/DeleteToolButton
@onready var upgrade_tool_button: Button = $Root/MainPanel/MainLayout/CraftContent/StorePanel/StoreLayout/StoreActionBar/UpgradeToolButton
@onready var craft_button_margin: MarginContainer = $Root/MainPanel/MainLayout/CraftContent/WorkbenchPanel/WorkbenchLayout/CraftButtonMargin
@onready var craft_button: Button = $Root/MainPanel/MainLayout/CraftContent/WorkbenchPanel/WorkbenchLayout/CraftButtonMargin/CraftButtonRow/CraftButton
@onready var inventory_panel: PanelContainer = $Root/MainPanel/MainLayout/CraftContent/InventoryPanel
@onready var sort_inventory_button: Button = $Root/MainPanel/MainLayout/CraftContent/InventoryPanel/InventoryLayout/InventorySidePanel/SortInventoryButton
@onready var tab_container: VBoxContainer = $Root/MainPanel/MainLayout/CraftContent/InventoryPanel/InventoryLayout/InventorySidePanel/TabContainer
@onready var inventory_grid: GridContainer = $Root/MainPanel/MainLayout/CraftContent/InventoryPanel/InventoryLayout/InventoryScroll/InventoryGrid
@onready var tooltip_panel: PanelContainer = $TooltipPanel
@onready var tooltip_name: Label = $TooltipPanel/TooltipBox/NameLabel
@onready var tooltip_type: Label = $TooltipPanel/TooltipBox/TypeLabel
@onready var tooltip_desc: Label = $TooltipPanel/TooltipBox/DescLabel
@onready var tooltip_props: Label = $TooltipPanel/TooltipBox/PropsLabel
@onready var fly_text_layer: Control = $FlyTextLayer
@onready var open_pack_overlay: PanelContainer = $OpenPackOverlay
@onready var open_pack_title: Label = $OpenPackOverlay/OpenPackCenter/OpenPackBox/OpenPackTitle
@onready var open_pack_result_grid: GridContainer = $OpenPackOverlay/OpenPackCenter/OpenPackBox/OpenPackResultGrid
@onready var open_pack_close_label: Label = $OpenPackOverlay/OpenPackCenter/OpenPackBox/CloseHintLabel
@onready var remove_material_overlay: PanelContainer = $RemoveMaterialOverlay
@onready var remove_material_title: Label = $RemoveMaterialOverlay/RemoveMaterialCenter/RemoveMaterialBox/RemoveMaterialTitle
@onready var remove_material_confirm_button: Button = $RemoveMaterialOverlay/RemoveMaterialCenter/RemoveMaterialBox/RemoveMaterialButtonRow/RemoveMaterialConfirmButton
@onready var remove_material_cancel_button: Button = $RemoveMaterialOverlay/RemoveMaterialCenter/RemoveMaterialBox/RemoveMaterialButtonRow/RemoveMaterialCancelButton
@onready var next_day_confirm_overlay: PanelContainer = $NextDayConfirmOverlay
@onready var next_day_confirm_title: Label = $NextDayConfirmOverlay/NextDayConfirmCenter/NextDayConfirmBox/NextDayConfirmTitle
@onready var next_day_confirm_desc: Label = $NextDayConfirmOverlay/NextDayConfirmCenter/NextDayConfirmBox/NextDayConfirmDesc
@onready var next_day_confirm_button: Button = $NextDayConfirmOverlay/NextDayConfirmCenter/NextDayConfirmBox/NextDayConfirmButtonRow/NextDayConfirmButton
@onready var next_day_cancel_button: Button = $NextDayConfirmOverlay/NextDayConfirmCenter/NextDayConfirmBox/NextDayConfirmButtonRow/NextDayCancelButton
@onready var upgrade_overlay: PanelContainer = $UpgradeOverlay
@onready var upgrade_title: Label = $UpgradeOverlay/UpgradeCenter/UpgradeBox/UpgradeTitle
@onready var upgrade_cost_row: HBoxContainer = $UpgradeOverlay/UpgradeCenter/UpgradeBox/UpgradeCostRow
@onready var upgrade_confirm_button: Button = $UpgradeOverlay/UpgradeCenter/UpgradeBox/UpgradeButtonRow/UpgradeConfirmButton
@onready var upgrade_cancel_button: Button = $UpgradeOverlay/UpgradeCenter/UpgradeBox/UpgradeButtonRow/UpgradeCancelButton

var inventory_items: Array = []
var material_items: Array = []
var material_slot_buttons: Array[Button] = []
var tab_buttons: Dictionary = {}
var base_item: Dictionary = {}
var current_category: String = CATEGORY_ALL
var current_mode: String = MODE_PREP
var prep_equipment: Dictionary = {}
var prep_map_item: Dictionary = {}
var crafted_count: int = 0
var gold: int = DEFAULT_START_GOLD
var hunger: int = DEFAULT_START_HUNGER
var max_hunger: int = DEFAULT_MAX_HUNGER
var map_element_items: Array = []
var map_element_by_id: Dictionary = {}
var map_pack_products: Array = []
var flip_rows: Dictionary = {}
var card_tool_mode: String = CARD_TOOL_NONE
var delete_tool_count: int = FLIP_DELETE_TOOL_START_COUNT
var upgrade_tool_count: int = FLIP_UPGRADE_TOOL_START_COUNT
var flip_next_day_requested: bool = false
var discovered_map_element_ids: Dictionary = {}
var pending_open_pack_items: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var base_has_pending_changes: bool = false
var pending_remove_material_index: int = -1
var pending_upgrade_item_index: int = -1
var preview_material_item: Dictionary = {}
var upgrade_candidate_buttons: Array[Button] = []
var blueprint_recipes: Array = []
var selected_blueprint: Dictionary = {}
var food_menu: PopupMenu
var pending_food_item: Dictionary = {}
var base_is_new_craft_result: bool = false
var build_tab_button: Button
var build_panel: PanelContainer
var build_tab_built_button: Button
var build_tab_unbuilt_button: Button
var build_content_list: VBoxContainer
var build_confirm_overlay: PanelContainer
var build_confirm_title: Label
var build_confirm_desc: Label
var build_confirm_detail_container: HBoxContainer
var build_confirm_button: Button
var build_cancel_button: Button
var current_build_tab: String = BUILD_TAB_UNBUILT
var facility_catalog: Array = []
var built_facilities: Array = []
var pending_build_facility: Dictionary = {}
#endregion

#region 3. 生命周期与核心逻辑
# 初始化界面状态、文本、信号、主题和测试背包数据。
func _ready() -> void:
	rng.randomize()
	_ensure_building_ui()
	tooltip_panel.visible = false
	tooltip_panel.z_index = 100
	open_pack_overlay.z_index = 20
	remove_material_overlay.z_index = 25
	next_day_confirm_overlay.z_index = 25
	upgrade_overlay.z_index = 25
	fly_text_layer.z_index = 30
	open_pack_overlay.visible = false
	remove_material_overlay.visible = false
	next_day_confirm_overlay.visible = false
	upgrade_overlay.visible = false
	build_confirm_overlay.visible = false
	_apply_ui_theme()
	title_label.text = _text("prep_title")
	store_title.text = "明日翻牌"
	result_title.text = _text("blueprint_title")
	craft_button.text = _text("craft")
	upgrade_button.text = _text("upgrade")
	sort_inventory_button.text = _text("sort_inventory")
	upgrade_button.visible = false
	upgrade_button.disabled = true
	prep_tab_button.text = _text("prep_tab")
	craft_tab_button.text = _text("craft_tab")
	shop_tab_button.text = _text("shop_tab")
	build_tab_button.text = "建造界面"
	flip_start_next_day_button.text = "开始下一天"
	character_visual_slot.text = _text("character_empty")
	prep_map_slot.text = _text("map_empty")
	next_day_confirm_title.text = _text("next_day_hunger_title")
	next_day_button.text = _text("next_day")
	open_pack_title.text = _text("open_pack_title")
	open_pack_close_label.text = _text("open_pack_close")
	remove_material_confirm_button.text = _text("confirm")
	remove_material_cancel_button.text = _text("cancel")
	next_day_confirm_button.text = _text("confirm")
	next_day_cancel_button.text = _text("cancel")
	upgrade_title.text = _text("upgrade_title")
	upgrade_confirm_button.text = _text("confirm")
	upgrade_cancel_button.text = _text("cancel")
	build_confirm_button.text = _text("confirm")
	build_cancel_button.text = _text("cancel")
	prep_tab_button.pressed.connect(_set_mode.bind(MODE_PREP))
	craft_tab_button.pressed.connect(_set_mode.bind(MODE_CRAFT))
	shop_tab_button.pressed.connect(_set_mode.bind(MODE_SHOP))
	build_tab_button.pressed.connect(_set_mode.bind(MODE_BUILD))
	build_tab_built_button.pressed.connect(_set_build_tab.bind(BUILD_TAB_BUILT))
	build_tab_unbuilt_button.pressed.connect(_set_build_tab.bind(BUILD_TAB_UNBUILT))
	base_slot.pressed.connect(_on_base_slot_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	prep_map_slot.pressed.connect(_on_prep_map_slot_pressed)
	next_day_button.pressed.connect(_on_next_day_pressed)
	_connect_prep_equip_slots()
	craft_button.pressed.connect(_on_craft_pressed)
	sort_inventory_button.pressed.connect(_on_sort_inventory_pressed)
	flip_start_next_day_button.pressed.connect(_on_flip_start_next_day_pressed)
	delete_tool_button.pressed.connect(_on_delete_tool_pressed)
	upgrade_tool_button.pressed.connect(_on_upgrade_tool_pressed)
	store_panel.gui_input.connect(_on_store_panel_gui_input)
	open_pack_overlay.gui_input.connect(_on_open_pack_overlay_gui_input)
	remove_material_confirm_button.pressed.connect(_on_remove_material_confirm_pressed)
	remove_material_cancel_button.pressed.connect(_hide_remove_material_dialog)
	next_day_confirm_button.pressed.connect(_on_next_day_confirm_pressed)
	next_day_cancel_button.pressed.connect(_hide_next_day_confirm_dialog)
	upgrade_confirm_button.pressed.connect(_on_upgrade_confirm_pressed)
	upgrade_cancel_button.pressed.connect(_hide_upgrade_dialog)
	build_confirm_button.pressed.connect(_on_build_confirm_pressed)
	build_cancel_button.pressed.connect(_hide_build_confirm_dialog)
	food_menu = PopupMenu.new()
	add_child(food_menu)
	food_menu.id_pressed.connect(_on_food_menu_id_pressed)
	_build_tabs()
	blueprint_recipes = _make_test_blueprint_recipes()
	facility_catalog = _make_test_facility_catalog()
	_update_gold_label()
	_apply_mode()
	if use_config_items:
		_set_shop_source_items(_load_map_element_config_items())
	set_inventory_items(_make_test_prep_items())

# 设置背包物品数据，并刷新界面。
func set_inventory_items(items: Array) -> void:
	inventory_items.clear()
	for item in items:
		if item is Dictionary:
			var item_data: Dictionary = (item as Dictionary).duplicate(true)
			_apply_test_map_hunger_rules(item_data)
			inventory_items.append(item_data)
	_refresh_all()

# 添加本次探索新增物品，并放到背包最前方标记未读。
func add_new_inventory_items(items: Array) -> void:
	for i in range(items.size() - 1, -1, -1):
		var item: Variant = items[i]
		if item is Dictionary:
			_add_new_item_to_inventory(item as Dictionary)
	_refresh_inventory()

# 生成准备界面测试用装备和道具。
func _make_test_prep_items() -> Array:
	var items: Array = []
	items.append(_make_test_equip_item("test_helmet", "旧铁盔", "helmet", "common", true, 2, {
		"防御": 2,
		"生命": 5
	}, "带裂纹的旧铁盔，可以作为装备基底测试镶嵌和升级。"))
	items.append(_make_test_equip_item("test_armor", "补丁皮甲", "armor", "common", true, 2, {
		"防御": 3,
		"闪避": 1
	}, "多处缝补的皮甲，可以作为护甲基底。"))
	items.append(_make_test_equip_item("test_pants", "旅人长裤", "pants", "common", true, 2, {
		"防御": 1,
		"行动": 1
	}, "方便移动的旧长裤，可以作为裤子基底。"))
	items.append(_make_test_equip_item("test_shoes", "硬底靴", "shoes", "common", true, 2, {
		"行动": 2,
		"闪避": 1
	}, "硬底靴适合长途探索，可以作为鞋子基底。"))
	items.append(_make_test_equip_item("test_weapon", "旧木剑", "weapon", "common", true, 2, {
		"攻击": 3
	}, "训练用旧木剑，可以作为武器基底测试合成升级。"))
	items.append(_make_test_equip_item("test_accessory", "裂纹护符", "accessory", "rare", true, 2, {
		"幸运": 2,
		"精神": 1
	}, "边缘有裂纹的护符，可以作为饰品基底。"))
	items.append(_make_test_equip_item("test_torch", "备用火把", "tool_1", "common", false, 2, {
		"视野": 2
	}, "营地备用火把，用于测试道具槽装配，不可作为基底。"))
	items.append(_make_test_equip_item("test_bandage", "粗布绷带", "tool_2", "common", false, 3, {
		"治疗": 2
	}, "简单处理伤口的粗布绷带，用于测试道具槽。"))
	items.append(_make_test_equip_item("test_trap", "简易捕兽夹", "tool_1", "rare", false, 1, {
		"控制": 2
	}, "可以临时限制野兽行动的捕兽夹，用于测试道具替换。"))
	items.append(_make_test_material_item("mat_wood", "木材", "common", 5, {
		"材料": 1
	}, "基础木料，用于测试蓝图合成消耗。"))
	items.append(_make_test_material_item("mat_iron", "铁钉", "common", 1, {
		"材料": 1
	}, "少量铁钉，用于测试材料不足的红色状态。"))
	items.append(_make_test_material_item("mat_cloth", "粗布", "common", 4, {
		"材料": 1
	}, "粗糙布料，用于制作护具和道具。"))
	items.append(_make_test_material_item("mat_herb", "草药", "common", 2, {
		"材料": 1
	}, "野外采集的草药，用于制作恢复道具。"))
	items.append(_make_test_food_item("food_dry_ration", "干粮", "common", 3, 20, "便于携带的干粮，右键食用后增加饱食度。"))
	items.append(_make_test_food_item("food_smoked_meat", "熏肉", "rare", 2, 35, "营地保存的熏肉，右键食用后增加较多饱食度。"))
	return items

# 按统一字段结构生成一件测试装备或道具。
func _make_test_equip_item(
	item_id: String,
	item_name: String,
	equip_slot: String,
	quality: String,
	can_be_base: bool,
	count: int,
	props: Dictionary,
	description: String
) -> Dictionary:
	var item_data: Dictionary = {
		"id": item_id,
		"name": item_name,
		"base_name": item_name,
		"category": CATEGORY_EQUIPMENT,
		"equip_slot": equip_slot,
		"quality": quality,
		"description": description,
		"count": count,
		"is_base": can_be_base,
		"is_material": true,
		"is_map_element": false,
		"is_shop_item": false,
		"socket_count": 0,
		"base_props": props.duplicate(true),
		"embedded_materials": [],
		"props": props.duplicate(true)
	}
	if can_be_base:
		item_data["socket_count"] = _get_default_socket_count(item_data)
	return item_data

# 按统一字段结构生成一件测试材料。
func _make_test_material_item(item_id: String, item_name: String, quality: String, count: int, props: Dictionary, description: String) -> Dictionary:
	return {
		"id": item_id,
		"name": item_name,
		"base_name": item_name,
		"category": CATEGORY_MATERIAL,
		"quality": quality,
		"description": description,
		"count": count,
		"is_base": false,
		"is_material": true,
		"is_map_element": false,
		"is_shop_item": false,
		"socket_count": 0,
		"base_props": props.duplicate(true),
		"embedded_materials": [],
		"props": props.duplicate(true)
	}

# 按统一字段结构生成一件测试食物。
func _make_test_food_item(item_id: String, item_name: String, quality: String, count: int, hunger_value: int, description: String) -> Dictionary:
	return {
		"id": item_id,
		"name": item_name,
		"base_name": item_name,
		"category": CATEGORY_FOOD,
		"quality": quality,
		"description": description,
		"count": count,
		"is_base": false,
		"is_material": false,
		"is_map_element": false,
		"is_shop_item": false,
		"food_value": hunger_value,
		"props": {
			"饱食度": hunger_value
		}
	}

# 生成测试用蓝图列表，后续可替换为配置表读取。
func _make_test_blueprint_recipes() -> Array:
	return [
		{
			"id": "bp_wood_sword",
			"category": "武器",
			"name": "旧木剑",
			"result": _make_test_equip_item("crafted_wood_sword", "旧木剑", "weapon", "common", true, 1, {
				"攻击": 3
			}, "通过蓝图合成的基础武器。"),
			"requirements": [
				{"id": "mat_wood", "name": "木材", "count": 2},
				{"id": "mat_iron", "name": "铁钉", "count": 1}
			]
		},
		{
			"id": "bp_hide_armor",
			"category": "护甲",
			"name": "补丁皮甲",
			"result": _make_test_equip_item("crafted_hide_armor", "补丁皮甲", "armor", "common", true, 1, {
				"防御": 3,
				"闪避": 1
			}, "通过蓝图合成的基础护甲。"),
			"requirements": [
				{"id": "mat_cloth", "name": "粗布", "count": 3},
				{"id": "mat_iron", "name": "铁钉", "count": 2}
			]
		},
		{
			"id": "bp_bandage",
			"category": "道具",
			"name": "粗布绷带",
			"result": _make_test_equip_item("crafted_bandage", "粗布绷带", "tool_2", "common", false, 1, {
				"治疗": 2
			}, "通过蓝图合成的恢复道具。"),
			"requirements": [
				{"id": "mat_cloth", "name": "粗布", "count": 1},
				{"id": "mat_herb", "name": "草药", "count": 1}
			]
		},
		{
			"id": "bp_torch",
			"category": "资源",
			"name": "备用火把",
			"result": _make_test_equip_item("crafted_torch", "备用火把", "tool_1", "common", false, 1, {
				"视野": 2
			}, "通过蓝图合成的探索道具。"),
			"requirements": [
				{"id": "mat_wood", "name": "木材", "count": 1},
				{"id": "mat_cloth", "name": "粗布", "count": 1}
			]
		}
	]

# 为测试地图基底补齐饱食度入场需求。
func _apply_test_map_hunger_rules(item_data: Dictionary) -> void:
	if not _can_use_as_prep_map(item_data):
		return
	if item_data.has("hunger_cost"):
		return
	match str(item_data.get("quality", "common")).to_lower():
		"rare":
			item_data["hunger_cost"] = 40
		"epic":
			item_data["hunger_cost"] = 55
		"legendary":
			item_data["hunger_cost"] = 70
		_:
			item_data["hunger_cost"] = DEFAULT_MAP_HUNGER_COST
	item_data["hunger_debuff"] = DEFAULT_MAP_HUNGER_DEBUFF

# 设置商店卡包的地图元素来源数据。
func _set_shop_source_items(items: Array) -> void:
	map_element_items.clear()
	map_element_by_id.clear()
	for item in items:
		if item is Dictionary and bool(item.get("is_shop_item", false)):
			var map_item: Dictionary = (item as Dictionary).duplicate(true)
			map_item["count"] = 1
			map_element_items.append(map_item)
			map_element_by_id[str(map_item.get("id", ""))] = map_item
	_rebuild_pack_products()
	_rebuild_flip_rows()

# 设置外部基底筛选、材料筛选、预览和合成执行接口。
func set_rule_interfaces(new_base_filter: Callable, new_material_filter: Callable, new_preview_provider: Callable, new_craft_handler: Callable) -> void:
	base_filter = new_base_filter
	material_filter = new_material_filter
	result_preview_provider = new_preview_provider
	craft_handler = new_craft_handler
	_refresh_all()

# 清空合成台，并将台面物品退回背包。
func clear_workbench() -> void:
	if not base_item.is_empty():
		if selected_blueprint.is_empty():
			_prepare_base_for_return()
			_return_item_to_inventory(base_item)
		base_item.clear()
	material_items.clear()
	base_has_pending_changes = false
	base_is_new_craft_result = false
	selected_blueprint.clear()
	_refresh_all()

# 设置当前金币数量，并刷新金币显示。
func set_gold(value: int) -> void:
	gold = value
	_update_gold_label()

# 响应背包槽位点击事件，并执行对应界面逻辑。
func _on_inventory_slot_pressed(item_data: Dictionary) -> void:
	if current_mode == MODE_PREP:
		_on_prep_inventory_slot_pressed(item_data)
		return
	if current_mode == MODE_BUILD:
		return
	if current_mode == MODE_SHOP:
		return
	if not selected_blueprint.is_empty():
		_set_status(_text("status_invalid_material"))
		return
	if base_item.is_empty():
		if _can_use_as_base(item_data):
			_move_item_to_base(item_data)
		else:
			_set_status(_text("status_invalid_base"))
		return
	if _can_use_as_base(item_data):
		_replace_base_item(item_data)
		return
	if _can_use_as_material(item_data):
		_add_material(item_data)
	else:
		_set_status(_text("status_invalid_material"))

# 响应基底槽位点击事件，并执行对应界面逻辑。
func _on_base_slot_pressed() -> void:
	if base_item.is_empty():
		return
	_hide_material_preview()
	if not selected_blueprint.is_empty():
		base_item.clear()
		selected_blueprint.clear()
		material_items.clear()
		base_has_pending_changes = false
		_refresh_all()
		return
	_prepare_base_for_return()
	if base_is_new_craft_result:
		_add_new_item_to_inventory(base_item)
	else:
		_return_item_to_inventory(base_item)
	item_removed_from_table.emit(base_item)
	base_item.clear()
	material_items.clear()
	base_has_pending_changes = false
	base_is_new_craft_result = false
	_refresh_all()

# 响应材料槽位点击事件，并执行对应界面逻辑。
func _on_material_slot_pressed(index: int) -> void:
	if index < 0 or index >= material_items.size():
		return
	if index >= _get_embedded_material_count():
		_remove_pending_material(index)
		return
	_show_remove_material_dialog(index)

# 响应合成点击事件，并执行对应界面逻辑。
func _on_craft_pressed() -> void:
	if not _can_craft():
		return
	_hide_material_preview()
	if not selected_blueprint.is_empty():
		_craft_selected_blueprint()
		return
	craft_requested.emit(base_item, material_items)
	var result: Dictionary = _make_craft_result()
	base_item = result
	material_items = _get_embedded_materials(base_item)
	base_has_pending_changes = false
	base_is_new_craft_result = true
	_set_status(_text("status_crafted"))
	_refresh_all()

# 响应升级点击事件，并执行对应界面逻辑。
func _on_upgrade_pressed() -> void:
	if base_item.is_empty():
		return
	_hide_material_preview()
	if not _can_upgrade_base():
		_show_center_prompt(_text("status_upgrade_missing") % str(base_item.get("base_name", base_item.get("name", "-"))))
		return
	_show_upgrade_dialog()

# 切换准备、合成、商店三种界面模式。
func _set_mode(mode: String) -> void:
	current_mode = mode
	_hide_tooltip()
	_hide_material_preview()
	_apply_mode()

# 根据当前界面模式刷新显隐、标题和页签状态。
func _apply_mode() -> void:
	var is_prep: bool = current_mode == MODE_PREP
	var is_craft: bool = current_mode == MODE_CRAFT
	var is_shop: bool = current_mode == MODE_SHOP
	var is_build: bool = current_mode == MODE_BUILD
	prep_info_panel.visible = is_prep
	prep_panel.visible = is_prep
	result_panel.visible = is_craft
	workbench_panel.visible = is_craft
	store_panel.visible = is_shop
	build_panel.visible = is_build
	inventory_panel.visible = not is_shop and not is_build
	craft_button_margin.visible = is_craft
	gold_label.visible = is_craft
	prep_gold_label.visible = is_prep
	shop_gold_label.visible = is_shop
	prep_tab_button.button_pressed = is_prep
	craft_tab_button.button_pressed = is_craft
	shop_tab_button.button_pressed = is_shop
	build_tab_button.button_pressed = is_build
	_refresh_screen_tab_colors(is_prep, is_craft, is_shop, is_build)
	if is_prep:
		title_label.text = _text("prep_title")
	elif is_shop:
		title_label.text = "明日翻牌"
	elif is_build:
		title_label.text = "营地建造"
	else:
		title_label.text = _text("title")
	if is_shop:
		_refresh_flip_cards()
	if is_build:
		_refresh_building_panel()
	_refresh_prep_all()

# 响应卡包滚动界面输入事件，并执行对应界面逻辑。
func _on_pack_scroll_gui_input(_event: InputEvent) -> void:
	pass

# 响应卡包点击事件，并执行对应界面逻辑。
func _on_pack_pressed(pack_data: Dictionary, source_button: Control) -> void:
	if int(pack_data.get("stock", 0)) <= 0:
		return
	var price: int = int(pack_data.get("price", DEFAULT_PACK_PRICE))
	pack_data["stock"] = int(pack_data.get("stock", 0)) - 1
	gold -= price
	_update_gold_label()
	_play_gold_cost_fly_text(source_button, price)
	var rewards: Array = _open_pack(pack_data)
	pending_open_pack_items = rewards
	_show_open_pack_overlay(rewards)
	_refresh_pack_products()

# 响应卡包弹窗界面输入事件，并执行对应界面逻辑。
func _on_open_pack_overlay_gui_input(event: InputEvent) -> void:
	if not open_pack_overlay.visible:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		_close_open_pack_overlay()
		open_pack_overlay.accept_event()

# 响应卸下材料确认点击事件，并执行对应界面逻辑。
func _on_remove_material_confirm_pressed() -> void:
	if pending_remove_material_index < 0 or pending_remove_material_index >= material_items.size():
		_hide_remove_material_dialog()
		return
	var item_data: Dictionary = material_items[pending_remove_material_index]
	material_items.remove_at(pending_remove_material_index)
	_return_item_to_inventory(item_data)
	item_removed_from_table.emit(item_data)
	_sync_base_embedded_materials()
	base_item = _make_socket_result(base_item, material_items, false)
	base_has_pending_changes = false
	base_is_new_craft_result = true
	_hide_remove_material_dialog()
	_refresh_all()

# 响应升级确认点击事件，并执行对应界面逻辑。
func _on_upgrade_confirm_pressed() -> void:
	if pending_upgrade_item_index < 0:
		return
	_hide_material_preview()
	_consume_upgrade_base(pending_upgrade_item_index)
	base_item = _make_upgrade_result(base_item)
	material_items = _get_embedded_materials(base_item)
	base_has_pending_changes = false
	base_is_new_craft_result = true
	_hide_upgrade_dialog()
	_set_status(_text("status_upgraded"))
	_refresh_all()
#endregion

#region 4. 辅助方法
# 创建材料槽位所需的控件或数据。
func _ensure_building_ui() -> void:
	if is_instance_valid(build_panel):
		return
	build_tab_button = Button.new()
	build_tab_button.name = "BuildTabButton"
	build_tab_button.custom_minimum_size = Vector2(96, 34)
	build_tab_button.focus_mode = Control.FOCUS_NONE
	build_tab_button.toggle_mode = true
	screen_tab_bar.add_child(build_tab_button)
	build_panel = PanelContainer.new()
	build_panel.name = "BuildPanel"
	build_panel.visible = false
	build_panel.custom_minimum_size = Vector2(520, 0)
	build_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_panel.size_flags_stretch_ratio = 2.0
	craft_content.add_child(build_panel)
	var build_layout: VBoxContainer = VBoxContainer.new()
	build_layout.name = "BuildLayout"
	build_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_layout.add_theme_constant_override("separation", 8)
	build_panel.add_child(build_layout)
	var sub_tab_bar: HBoxContainer = HBoxContainer.new()
	sub_tab_bar.name = "BuildSubTabBar"
	sub_tab_bar.add_theme_constant_override("separation", 8)
	build_layout.add_child(sub_tab_bar)
	build_tab_built_button = _make_build_subtab_button("已建造")
	sub_tab_bar.add_child(build_tab_built_button)
	build_tab_unbuilt_button = _make_build_subtab_button("未建造")
	sub_tab_bar.add_child(build_tab_unbuilt_button)
	var build_scroll: ScrollContainer = ScrollContainer.new()
	build_scroll.name = "BuildScroll"
	build_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	build_layout.add_child(build_scroll)
	build_content_list = VBoxContainer.new()
	build_content_list.name = "BuildContentList"
	build_content_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_content_list.add_theme_constant_override("separation", 10)
	build_scroll.add_child(build_content_list)
	_ensure_build_confirm_overlay()

func _make_build_subtab_button(label_text: String) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(120, 36)
	return button

func _ensure_build_confirm_overlay() -> void:
	build_confirm_overlay = PanelContainer.new()
	build_confirm_overlay.name = "BuildConfirmOverlay"
	build_confirm_overlay.visible = false
	build_confirm_overlay.z_index = 25
	build_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	build_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(build_confirm_overlay)
	var confirm_center: CenterContainer = CenterContainer.new()
	confirm_center.name = "BuildConfirmCenter"
	build_confirm_overlay.add_child(confirm_center)
	var confirm_box: VBoxContainer = VBoxContainer.new()
	confirm_box.name = "BuildConfirmBox"
	confirm_box.custom_minimum_size = Vector2(460, 220)
	confirm_box.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_box.add_theme_constant_override("separation", 14)
	confirm_center.add_child(confirm_box)
	build_confirm_title = Label.new()
	build_confirm_title.name = "BuildConfirmTitle"
	build_confirm_title.add_theme_font_size_override("font_size", 20)
	build_confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_box.add_child(build_confirm_title)
	build_confirm_desc = Label.new()
	build_confirm_desc.name = "BuildConfirmDesc"
	build_confirm_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_confirm_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_box.add_child(build_confirm_desc)
	build_confirm_detail_container = HBoxContainer.new()
	build_confirm_detail_container.name = "BuildConfirmDetail"
	build_confirm_detail_container.alignment = BoxContainer.ALIGNMENT_CENTER
	build_confirm_detail_container.add_theme_constant_override("separation", 16)
	confirm_box.add_child(build_confirm_detail_container)
	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.name = "BuildConfirmButtonRow"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	confirm_box.add_child(button_row)
	build_confirm_button = Button.new()
	build_confirm_button.custom_minimum_size = Vector2(120, 34)
	button_row.add_child(build_confirm_button)
	build_cancel_button = Button.new()
	build_cancel_button.custom_minimum_size = Vector2(120, 34)
	button_row.add_child(build_cancel_button)

func _build_material_slots(slot_count: int) -> void:
	for child in material_grid.get_children():
		child.queue_free()
	material_slot_buttons.clear()
	for i in range(slot_count):
		var slot: Button = _make_slot_button(_text("material_empty"), false)
		slot.pressed.connect(_on_material_slot_pressed.bind(i))
		material_grid.add_child(slot)
		material_slot_buttons.append(slot)

# 创建分类页签所需的控件或数据。
func _build_tabs() -> void:
	for child in tab_container.get_children():
		child.queue_free()
	tab_buttons.clear()
	var tabs: Array = [
		{"id": CATEGORY_ALL, "name": _text("all")},
		{"id": CATEGORY_EQUIPMENT, "name": _text("equipment")},
		{"id": CATEGORY_MAP, "name": _text("map")},
		{"id": CATEGORY_MATERIAL, "name": _text("material")},
		{"id": CATEGORY_FOOD, "name": _text("food")}
	]
	for tab in tabs:
		var button: Button = Button.new()
		button.text = tab["name"]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(78, 34)
		button.add_theme_font_size_override("font_size", 12)
		_apply_button_style(button, Color(0.23, 0.20, 0.30), Color(0.48, 0.38, 0.66), Color(0.34, 0.29, 0.43), Color(0.18, 0.15, 0.24))
		button.pressed.connect(_on_tab_pressed.bind(tab["id"]))
		tab_container.add_child(button)
		tab_buttons[tab["id"]] = button

# 统一应用准备、合成、商店三个界面的颜色层级和按钮样式。
func _apply_ui_theme() -> void:
	_apply_panel_style(main_panel, Color(0.11, 0.12, 0.14), Color(0.32, 0.34, 0.38), 2)
	_apply_panel_style(character_info_panel, Color(0.18, 0.15, 0.11), Color(0.70, 0.50, 0.24), 2)
	_apply_panel_style(map_info_panel, Color(0.10, 0.16, 0.15), Color(0.27, 0.55, 0.45), 2)
	_apply_empty_panel_style(prep_panel)
	_apply_panel_style(character_loadout_panel, Color(0.18, 0.15, 0.11), Color(0.70, 0.50, 0.24), 2)
	_apply_panel_style(map_prep_panel, Color(0.12, 0.18, 0.14), Color(0.43, 0.66, 0.35), 2)
	_apply_panel_style(result_panel, Color(0.08, 0.14, 0.22), Color(0.20, 0.42, 0.62), 2)
	_apply_panel_style(workbench_panel, Color(0.17, 0.13, 0.09), Color(0.72, 0.48, 0.18), 3)
	_apply_panel_style(base_result_panel, Color(0.08, 0.14, 0.22), Color(0.20, 0.42, 0.62), 2)
	_apply_panel_style(store_panel, Color(0.08, 0.17, 0.12), Color(0.27, 0.62, 0.38), 3)
	_apply_panel_style(inventory_panel, Color(0.14, 0.12, 0.19), Color(0.43, 0.32, 0.62), 2)
	_apply_panel_style(tooltip_panel, Color(0.79, 0.55, 0.18), Color(0.98, 0.84, 0.42), 2)
	_apply_panel_style(next_day_confirm_overlay, Color(0.08, 0.06, 0.05, 0.86), Color(0.80, 0.38, 0.18), 2)
	_apply_panel_style(build_panel, Color(0.11, 0.16, 0.18), Color(0.35, 0.62, 0.66), 3)
	_apply_panel_style(build_confirm_overlay, Color(0.05, 0.07, 0.08, 0.88), Color(0.35, 0.62, 0.66), 2)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.58))
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.26))
	prep_gold_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.26))
	shop_gold_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.26))
	hunger_label.add_theme_color_override("font_color", Color(0.95, 0.80, 0.42))
	map_warning_label.add_theme_color_override("font_color", Color(1.0, 0.52, 0.36))
	_apply_button_style(craft_button, Color(0.70, 0.42, 0.10), Color(0.95, 0.70, 0.28), Color(0.88, 0.55, 0.14), Color(0.28, 0.22, 0.16))
	_apply_button_style(next_day_button, Color(0.22, 0.50, 0.25), Color(0.48, 0.80, 0.42), Color(0.32, 0.64, 0.32), Color(0.12, 0.20, 0.14))
	_apply_button_style(upgrade_button, Color(0.42, 0.29, 0.10), Color(0.82, 0.62, 0.24), Color(0.55, 0.38, 0.14), Color(0.22, 0.18, 0.12))
	_apply_button_style(sort_inventory_button, Color(0.20, 0.24, 0.34), Color(0.46, 0.54, 0.78), Color(0.26, 0.32, 0.45), Color(0.13, 0.15, 0.20))
	_apply_button_style(build_tab_built_button, Color(0.16, 0.25, 0.27), Color(0.34, 0.62, 0.66), Color(0.22, 0.34, 0.36), Color(0.10, 0.12, 0.13))
	_apply_button_style(build_tab_unbuilt_button, Color(0.16, 0.25, 0.27), Color(0.34, 0.62, 0.66), Color(0.22, 0.34, 0.36), Color(0.10, 0.12, 0.13))
	_apply_button_style(build_confirm_button, Color(0.22, 0.50, 0.25), Color(0.48, 0.80, 0.42), Color(0.32, 0.64, 0.32), Color(0.12, 0.20, 0.14))
	_apply_button_style(build_cancel_button, Color(0.34, 0.22, 0.20), Color(0.68, 0.42, 0.36), Color(0.45, 0.28, 0.24), Color(0.14, 0.12, 0.12))
	_apply_button_style(character_visual_slot, Color(0.17, 0.19, 0.22), Color(0.45, 0.50, 0.56), Color(0.20, 0.24, 0.28), Color(0.12, 0.13, 0.15))
	_apply_button_style(prep_map_slot, Color(0.13, 0.24, 0.15), Color(0.42, 0.68, 0.36), Color(0.20, 0.34, 0.20), Color(0.10, 0.16, 0.10))
	_apply_equip_slot_button_style(helmet_slot)
	_apply_equip_slot_button_style(armor_slot)
	_apply_equip_slot_button_style(pants_slot)
	_apply_equip_slot_button_style(shoes_slot)
	_apply_equip_slot_button_style(weapon_slot)
	_apply_equip_slot_button_style(accessory_slot)
	_apply_tool_slot_button_style(tool_1_slot)
	_apply_tool_slot_button_style(tool_2_slot)

# 应用面板背景、边框和内边距样式。
func _apply_panel_style(panel: PanelContainer, bg_color: Color, border_color: Color, border_width: int) -> void:
	panel.add_theme_stylebox_override("panel", _make_panel_style(bg_color, border_color, border_width))

# 应用透明无边框的面板样式。
func _apply_empty_panel_style(panel: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_content_margin_all(0.0)
	panel.add_theme_stylebox_override("panel", style)

# 生成面板样式所需的数据或控件。
func _make_panel_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8.0)
	return style

# 应用按钮普通、悬停、按下和禁用状态样式。
func _apply_button_style(button: Button, bg_color: Color, border_color: Color, hover_color: Color, disabled_color: Color) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(bg_color, border_color, 1))
	button.add_theme_stylebox_override("hover", _make_button_style(hover_color, border_color, 2))
	button.add_theme_stylebox_override("pressed", _make_button_style(hover_color, Color(1.0, 0.82, 0.35), 2))
	button.add_theme_stylebox_override("disabled", _make_button_style(disabled_color, Color(0.30, 0.30, 0.30), 1))
	button.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.82))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.48))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))

# 生成按钮样式所需的数据或控件。
func _make_button_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(6.0)
	return style

# 应用装备槽位按钮样式样式或状态。
func _apply_equip_slot_button_style(button: Button) -> void:
	_apply_button_style(button, Color(0.21, 0.18, 0.13), Color(0.62, 0.46, 0.22), Color(0.31, 0.25, 0.16), Color(0.12, 0.11, 0.10))

# 应用tool槽位按钮样式样式或状态。
func _apply_tool_slot_button_style(button: Button) -> void:
	_apply_button_style(button, Color(0.14, 0.20, 0.16), Color(0.36, 0.58, 0.40), Color(0.20, 0.30, 0.22), Color(0.10, 0.12, 0.10))

# 刷新界面页签颜色的界面显示或状态。
func _refresh_screen_tab_colors(is_prep: bool, is_craft: bool, is_shop: bool, is_build: bool) -> void:
	_apply_screen_tab_style(prep_tab_button, is_prep, Color(0.60, 0.38, 0.16), Color(0.80, 0.58, 0.26))
	_apply_screen_tab_style(craft_tab_button, is_craft, Color(0.60, 0.38, 0.16), Color(0.80, 0.58, 0.26))
	_apply_screen_tab_style(shop_tab_button, is_shop, Color(0.20, 0.46, 0.26), Color(0.36, 0.70, 0.40))
	_apply_screen_tab_style(build_tab_button, is_build, Color(0.18, 0.48, 0.52), Color(0.38, 0.74, 0.78))

# 应用界面页签样式样式或状态。
func _apply_screen_tab_style(button: Button, selected: bool, selected_color: Color, selected_border: Color) -> void:
	if selected:
		_apply_button_style(button, selected_color, selected_border, Color(selected_color.r + 0.08, selected_color.g + 0.08, selected_color.b + 0.08), Color(0.14, 0.14, 0.14))
	else:
		_apply_button_style(button, Color(0.18, 0.20, 0.24), Color(0.36, 0.40, 0.46), Color(0.25, 0.28, 0.34), Color(0.12, 0.12, 0.13))

# 响应页签点击事件，并执行对应界面逻辑。
func _on_tab_pressed(tab_id: String) -> void:
	current_category = tab_id
	_refresh_inventory()
	_refresh_tabs()

# 刷新all的界面显示或状态。
func _refresh_all() -> void:
	_refresh_prep_all()
	_refresh_base_slot()
	_refresh_material_slots()
	_refresh_result_list()
	_refresh_blueprint_list()
	_refresh_flip_cards()
	_refresh_building_panel()
	_refresh_inventory()
	_refresh_tabs()
	_update_craft_button()
	_update_gold_label()
	_emit_table_changed()

# 实现connect准备界面装备槽位的界面或数据处理逻辑。
func _connect_prep_equip_slots() -> void:
	helmet_slot.pressed.connect(_on_prep_equip_slot_pressed.bind("helmet"))
	armor_slot.pressed.connect(_on_prep_equip_slot_pressed.bind("armor"))
	pants_slot.pressed.connect(_on_prep_equip_slot_pressed.bind("pants"))
	shoes_slot.pressed.connect(_on_prep_equip_slot_pressed.bind("shoes"))
	weapon_slot.pressed.connect(_on_prep_equip_slot_pressed.bind("weapon"))
	accessory_slot.pressed.connect(_on_prep_equip_slot_pressed.bind("accessory"))
	tool_1_slot.pressed.connect(_on_prep_equip_slot_pressed.bind("tool_1"))
	tool_2_slot.pressed.connect(_on_prep_equip_slot_pressed.bind("tool_2"))

# 响应准备界面背包槽位点击事件，并执行对应界面逻辑。
func _on_prep_inventory_slot_pressed(item_data: Dictionary) -> void:
	if _can_use_as_prep_map(item_data):
		_set_prep_map(item_data)
		return
	var slot_id: String = _get_equip_slot_id(item_data)
	if slot_id.is_empty():
		_set_status(_text("status_invalid_material"))
		return
	_set_prep_equipment(slot_id, item_data)

# 设置准备界面装备数据，并同步刷新界面。
func _set_prep_equipment(slot_id: String, item_data: Dictionary) -> void:
	if prep_equipment.has(slot_id):
		var old_item: Dictionary = prep_equipment[slot_id] as Dictionary
		if not old_item.is_empty():
			_return_item_to_inventory(old_item)
	_take_item_from_inventory(item_data)
	var equip_item: Dictionary = item_data.duplicate(true)
	equip_item["count"] = 1
	prep_equipment[slot_id] = equip_item
	_refresh_prep_all()
	_refresh_inventory()

# 设置准备界面地图数据，并同步刷新界面。
func _set_prep_map(item_data: Dictionary) -> void:
	if not prep_map_item.is_empty():
		_return_item_to_inventory(prep_map_item)
	_take_item_from_inventory(item_data)
	prep_map_item = item_data.duplicate(true)
	_apply_test_map_hunger_rules(prep_map_item)
	prep_map_item["count"] = 1
	_refresh_prep_all()
	_refresh_inventory()

# 响应准备界面装备槽位点击事件，并执行对应界面逻辑。
func _on_prep_equip_slot_pressed(slot_id: String) -> void:
	if not prep_equipment.has(slot_id):
		return
	var item_data: Dictionary = prep_equipment[slot_id] as Dictionary
	if item_data.is_empty():
		return
	_return_item_to_inventory(item_data)
	prep_equipment.erase(slot_id)
	_refresh_prep_all()
	_refresh_inventory()

# 响应准备界面地图槽位点击事件，并执行对应界面逻辑。
func _on_prep_map_slot_pressed() -> void:
	if prep_map_item.is_empty():
		return
	_return_item_to_inventory(prep_map_item)
	prep_map_item.clear()
	_refresh_prep_all()
	_refresh_inventory()

# 响应下一天点击事件，并执行对应界面逻辑。
func _make_test_facility_catalog() -> Array:
	return [
		{
			"id": "food_room",
			"name": "食物制造间",
			"level": 1,
			"facility_type": FACILITY_TYPE_WORK,
			"type_name": "工作建筑",
			"description": "每回合提供基础食物收益，缓解进入明日地图前的饱食度压力。",
			"icon_path": "res://Resource/Tiny Swords (Free Pack)/Buildings/Blue Buildings/House1.png",
			"build_days": 1,
			"requirements": [
				{"id": "mat_wood", "name": "木材", "count": 2},
				{"id": "mat_cloth", "name": "粗布", "count": 1}
			],
			"effect_text": "每回合：食物 +1"
		},
		{
			"id": "wood_processor",
			"name": "木材加工厂",
			"level": 1,
			"facility_type": FACILITY_TYPE_WORK,
			"type_name": "工作建筑",
			"description": "每回合把营地杂料整理成可用于设施扩建的木材。",
			"icon_path": "res://Resource/Tiny Swords (Free Pack)/Buildings/Blue Buildings/House2.png",
			"build_days": 1,
			"requirements": [
				{"id": "mat_wood", "name": "木材", "count": 3},
				{"id": "mat_iron", "name": "铁钉", "count": 1}
			],
			"effect_text": "每回合：木材 +1"
		},
		{
			"id": "weather_tower",
			"name": "气象塔",
			"level": 2,
			"facility_type": FACILITY_TYPE_ENHANCE,
			"type_name": "增强建筑",
			"description": "把雷雨、浓雾、强风等天气牌加入明日牌库。",
			"icon_path": "res://Resource/Tiny Swords (Free Pack)/Buildings/Blue Buildings/Tower.png",
			"build_days": 2,
			"requirements": [
				{"id": "mat_wood", "name": "木材", "count": 4},
				{"id": "mat_iron", "name": "铁钉", "count": 2}
			],
			"effect_text": "一次性：天气牌进入明日牌库"
		},
		{
			"id": "geology_meter",
			"name": "地质仪",
			"level": 2,
			"facility_type": FACILITY_TYPE_ENHANCE,
			"type_name": "增强建筑",
			"description": "把火山、裂隙、矿脉暴露等地形牌加入明日牌库。",
			"icon_path": "res://Resource/Tiny Swords (Free Pack)/Buildings/Blue Buildings/Monastery.png",
			"build_days": 2,
			"requirements": [
				{"id": "mat_iron", "name": "铁钉", "count": 3},
				{"id": "mat_wood", "name": "木材", "count": 2}
			],
			"effect_text": "一次性：地形牌进入明日牌库"
		},
		{
			"id": "observation_table",
			"name": "观测牌桌",
			"level": 3,
			"facility_type": FACILITY_TYPE_ENHANCE,
			"type_name": "增强建筑",
			"description": "每天可以查看一张盖着的明日牌类型，让继续翻牌变成可规划风险。",
			"icon_path": "res://Resource/Tiny Swords (Free Pack)/Buildings/Blue Buildings/Archery.png",
			"build_days": 3,
			"requirements": [
				{"id": "mat_wood", "name": "木材", "count": 5},
				{"id": "mat_cloth", "name": "粗布", "count": 3},
				{"id": "mat_herb", "name": "草药", "count": 1}
			],
			"effect_text": "一次性解锁：查看盖牌类型"
		}
	]

func _set_build_tab(tab_id: String) -> void:
	current_build_tab = tab_id
	_refresh_building_panel()

func _refresh_building_panel() -> void:
	if not is_instance_valid(build_content_list):
		return
	build_tab_built_button.button_pressed = current_build_tab == BUILD_TAB_BUILT
	build_tab_unbuilt_button.button_pressed = current_build_tab == BUILD_TAB_UNBUILT
	for child in build_content_list.get_children():
		child.queue_free()
	if current_build_tab == BUILD_TAB_BUILT:
		_refresh_built_facilities()
	else:
		_refresh_unbuilt_facilities()

func _refresh_built_facilities() -> void:
	var work_row: HFlowContainer = _add_build_card_group("工作建筑")
	var has_work: bool = _add_built_facility_cards(FACILITY_TYPE_WORK, work_row)
	if not has_work:
		_add_empty_build_line_to(work_row, "暂无工作建筑")
	var enhance_row: HFlowContainer = _add_build_card_group("增强建筑")
	var has_enhance: bool = _add_built_facility_cards(FACILITY_TYPE_ENHANCE, enhance_row)
	if not has_enhance:
		_add_empty_build_line_to(enhance_row, "暂无增强建筑")

func _add_built_facility_cards(facility_type: String, row: HFlowContainer) -> bool:
	var has_any: bool = false
	for state_value in built_facilities:
		if not (state_value is Dictionary):
			continue
		var state: Dictionary = state_value as Dictionary
		var facility: Dictionary = _get_facility_by_id(str(state.get("id", "")))
		if facility.is_empty() or str(facility.get("facility_type", "")) != facility_type:
			continue
		row.add_child(_make_built_facility_card(facility, state))
		has_any = true
	return has_any

func _refresh_unbuilt_facilities() -> void:
	var facilities: Array = _get_unbuilt_facilities_sorted()
	var current_group: String = ""
	var current_row: HFlowContainer = null
	for facility_value in facilities:
		var facility: Dictionary = facility_value as Dictionary
		var group_name: String = "Lv.%d  %s" % [int(facility.get("level", 1)), str(facility.get("type_name", "-"))]
		if group_name != current_group:
			current_group = group_name
			current_row = _add_build_card_group(current_group)
		if current_row:
			current_row.add_child(_make_unbuilt_facility_card(facility))
	if facilities.is_empty():
		_add_empty_build_line("所有建筑均已建造或正在建造")

func _get_unbuilt_facilities_sorted() -> Array:
	var result: Array = []
	for facility_value in facility_catalog:
		if not (facility_value is Dictionary):
			continue
		var facility: Dictionary = facility_value as Dictionary
		if _has_facility_state(str(facility.get("id", ""))):
			continue
		result.append(facility)
	result.sort_custom(_sort_unbuilt_facility)
	return result

func _sort_unbuilt_facility(a: Dictionary, b: Dictionary) -> bool:
	var level_a: int = int(a.get("level", 1))
	var level_b: int = int(b.get("level", 1))
	if level_a != level_b:
		return level_a < level_b
	var type_a: int = _get_facility_type_sort(str(a.get("facility_type", "")))
	var type_b: int = _get_facility_type_sort(str(b.get("facility_type", "")))
	if type_a != type_b:
		return type_a < type_b
	var can_a: bool = _can_start_facility_build(a)
	var can_b: bool = _can_start_facility_build(b)
	if can_a != can_b:
		return can_a
	return str(a.get("name", "")) < str(b.get("name", ""))

func _get_facility_type_sort(facility_type: String) -> int:
	if facility_type == FACILITY_TYPE_WORK:
		return 10
	if facility_type == FACILITY_TYPE_ENHANCE:
		return 20
	return 99

func _make_unbuilt_facility_card(facility: Dictionary) -> PanelContainer:
	var can_build: bool = _can_start_facility_build(facility)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(188, 250)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if can_build else Control.MOUSE_FILTER_IGNORE
	_bind_facility_tooltip(panel, facility)
	if can_build:
		_apply_panel_style(panel, Color(0.13, 0.30, 0.17), Color(0.42, 0.74, 0.40), 2)
		panel.gui_input.connect(_on_unbuilt_facility_card_input.bind(facility))
	else:
		_apply_panel_style(panel, Color(0.16, 0.17, 0.18), Color(0.36, 0.38, 0.42), 1)
	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 6)
	panel.add_child(info_box)
	var title: Label = Label.new()
	title.text = str(facility.get("name", "-"))
	title.add_theme_font_size_override("font_size", 17)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", Color(0.92, 0.95, 0.86) if can_build else Color(0.72, 0.74, 0.74))
	info_box.add_child(title)
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(128, 92)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = _get_facility_icon(facility)
	info_box.add_child(icon_rect)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_box.add_child(spacer)
	var material_box: HFlowContainer = HFlowContainer.new()
	material_box.custom_minimum_size = Vector2(0, 58)
	material_box.add_theme_constant_override("h_separation", 6)
	material_box.add_theme_constant_override("v_separation", 6)
	info_box.add_child(material_box)
	for requirement_value in _get_facility_requirements_sorted(facility):
		var requirement: Dictionary = requirement_value as Dictionary
		var item_id: String = str(requirement.get("id", ""))
		var have_count: int = _get_inventory_count_by_id(item_id)
		var need_count: int = int(requirement.get("count", 0))
		material_box.add_child(_make_facility_material_badge(requirement, have_count >= need_count))
	var time_label: Label = Label.new()
	time_label.text = "%d天后" % int(facility.get("build_days", 1))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.34))
	info_box.add_child(time_label)
	return panel

func _on_unbuilt_facility_card_input(event: InputEvent, facility: Dictionary) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_show_build_confirm_dialog(facility)

func _make_facility_material_badge(requirement: Dictionary, is_enough: bool) -> PanelContainer:
	var badge: PanelContainer = PanelContainer.new()
	badge.custom_minimum_size = Vector2(52, 52)
	var bg_color: Color = Color(0.12, 0.24, 0.15) if is_enough else Color(0.24, 0.13, 0.12)
	var border_color: Color = Color(0.38, 0.72, 0.35) if is_enough else Color(0.72, 0.32, 0.28)
	_apply_panel_style(badge, bg_color, border_color, 1)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	badge.add_child(box)
	var icon_label: Label = Label.new()
	icon_label.text = _get_material_icon_text(str(requirement.get("id", "")), str(requirement.get("name", "")))
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 16)
	box.add_child(icon_label)
	var count_label: Label = Label.new()
	count_label.text = "x%d" % int(requirement.get("count", 0))
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.82))
	box.add_child(count_label)
	return badge

func _get_facility_icon(facility: Dictionary) -> Texture2D:
	var icon_path: String = str(facility.get("icon_path", ""))
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D

func _get_material_icon_text(item_id: String, item_name: String) -> String:
	if item_id.contains("wood"):
		return "木"
	if item_id.contains("iron"):
		return "铁"
	if item_id.contains("cloth"):
		return "布"
	if item_id.contains("herb"):
		return "草"
	if item_name.is_empty():
		return "材"
	return item_name.substr(0, 1)

func _bind_facility_tooltip(slot: Control, facility: Dictionary) -> void:
	_bind_tooltip(slot, _make_facility_tooltip_data(facility))

func _make_facility_tooltip_data(facility: Dictionary) -> Dictionary:
	return {
		"id": str(facility.get("id", "")),
		"name": "%s  Lv.%d" % [str(facility.get("name", "-")), int(facility.get("level", 1))],
		"category": CATEGORY_MATERIAL,
		"description": str(facility.get("description", "")),
		"quality": "common",
		"props": {
			"类型": str(facility.get("type_name", "-")),
			"建造时间": "%d天后" % int(facility.get("build_days", 1)),
			"效果": str(facility.get("effect_text", "")),
			"材料": _format_facility_requirements(facility)
		}
	}

func _make_built_facility_card(facility: Dictionary, state: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(188, 230)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_bind_facility_tooltip(panel, facility)
	var is_building: bool = int(state.get("remaining_days", 0)) > 0
	var bg: Color = Color(0.18, 0.16, 0.12) if is_building else Color(0.12, 0.20, 0.16)
	var border: Color = Color(0.74, 0.55, 0.24) if is_building else Color(0.36, 0.70, 0.40)
	_apply_panel_style(panel, bg, border, 2)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 17)
	title.text = str(facility.get("name", "-"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(128, 92)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = _get_facility_icon(facility)
	box.add_child(icon_rect)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var state_label: Label = Label.new()
	if is_building:
		state_label.text = "建造中：剩余%d天" % int(state.get("remaining_days", 0))
		state_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.34))
	else:
		state_label.text = "已生效"
		state_label.add_theme_color_override("font_color", Color(0.60, 0.95, 0.58))
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(state_label)
	return panel

func _format_unbuilt_facility_text(facility: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("%s  Lv.%d  [%s]" % [str(facility.get("name", "-")), int(facility.get("level", 1)), str(facility.get("type_name", "-"))])
	lines.append(str(facility.get("description", "")))
	lines.append(str(facility.get("effect_text", "")))
	lines.append("时间：%d天后" % int(facility.get("build_days", 1)))
	lines.append("材料：%s" % _format_facility_requirements(facility))
	return "\n".join(lines)

func _format_facility_requirements(facility: Dictionary) -> String:
	var parts: Array[String] = []
	for requirement_value in _get_facility_requirements_sorted(facility):
		var requirement: Dictionary = requirement_value as Dictionary
		var item_id: String = str(requirement.get("id", ""))
		var have_count: int = _get_inventory_count_by_id(item_id)
		var need_count: int = int(requirement.get("count", 0))
		parts.append("%s %d(当前)/%d(所需)" % [str(requirement.get("name", item_id)), have_count, need_count])
	return "，".join(parts)

func _show_build_confirm_dialog(facility: Dictionary) -> void:
	if not _can_start_facility_build(facility):
		return
	pending_build_facility = facility.duplicate(true)
	build_confirm_title.text = "确认建造：%s" % str(facility.get("name", "-"))
	build_confirm_desc.text = "将消耗：%s\n建造时间：%d天后" % [_format_facility_requirements(facility), int(facility.get("build_days", 1))]
	build_confirm_overlay.visible = true

func _hide_build_confirm_dialog() -> void:
	pending_build_facility.clear()
	build_confirm_overlay.visible = false

func _on_build_confirm_pressed() -> void:
	if pending_build_facility.is_empty():
		_hide_build_confirm_dialog()
		return
	if not _can_start_facility_build(pending_build_facility):
		_hide_build_confirm_dialog()
		_refresh_building_panel()
		return
	for requirement_value in _get_facility_requirements(pending_build_facility):
		var requirement: Dictionary = requirement_value as Dictionary
		_take_item_count_from_inventory(str(requirement.get("id", "")), int(requirement.get("count", 0)))
	built_facilities.append({
		"id": str(pending_build_facility.get("id", "")),
		"remaining_days": max(1, int(pending_build_facility.get("build_days", 1))),
		"is_active": false
	})
	_hide_build_confirm_dialog()
	current_build_tab = BUILD_TAB_BUILT
	_refresh_all()

func _advance_facility_build_days() -> void:
	for state_value in built_facilities:
		if not (state_value is Dictionary):
			continue
		var state: Dictionary = state_value as Dictionary
		var remaining_days: int = int(state.get("remaining_days", 0))
		if remaining_days <= 0:
			continue
		remaining_days -= 1
		state["remaining_days"] = remaining_days
		if remaining_days <= 0:
			state["is_active"] = true

func _can_start_facility_build(facility: Dictionary) -> bool:
	for requirement_value in _get_facility_requirements(facility):
		var requirement: Dictionary = requirement_value as Dictionary
		if _get_inventory_count_by_id(str(requirement.get("id", ""))) < int(requirement.get("count", 0)):
			return false
	return true

func _get_facility_requirements(facility: Dictionary) -> Array:
	var result: Array = []
	var requirements: Array = facility.get("requirements", []) as Array
	for requirement_value in requirements:
		if requirement_value is Dictionary:
			result.append(requirement_value as Dictionary)
	return result

func _get_facility_requirements_sorted(facility: Dictionary) -> Array:
	var result: Array = _get_facility_requirements(facility)
	result.sort_custom(_sort_facility_requirement)
	return result

func _sort_facility_requirement(a: Dictionary, b: Dictionary) -> bool:
	var have_a: int = _get_inventory_count_by_id(str(a.get("id", "")))
	var need_a: int = int(a.get("count", 0))
	var have_b: int = _get_inventory_count_by_id(str(b.get("id", "")))
	var need_b: int = int(b.get("count", 0))
	var enough_a: bool = have_a >= need_a
	var enough_b: bool = have_b >= need_b
	if enough_a != enough_b:
		return enough_a
	return str(a.get("name", a.get("id", ""))) < str(b.get("name", b.get("id", "")))

func _has_facility_state(facility_id: String) -> bool:
	for state_value in built_facilities:
		if state_value is Dictionary and str((state_value as Dictionary).get("id", "")) == facility_id:
			return true
	return false

func _get_facility_by_id(facility_id: String) -> Dictionary:
	for facility_value in facility_catalog:
		if facility_value is Dictionary and str((facility_value as Dictionary).get("id", "")) == facility_id:
			return facility_value as Dictionary
	return {}

func _add_build_section(title_text: String) -> void:
	var label: Label = Label.new()
	label.text = title_text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.68))
	build_content_list.add_child(label)

func _add_build_card_group(title_text: String) -> HFlowContainer:
	var group_box: VBoxContainer = VBoxContainer.new()
	group_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_box.add_theme_constant_override("separation", 8)
	build_content_list.add_child(group_box)
	var label: Label = Label.new()
	label.text = title_text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.68))
	group_box.add_child(label)
	var row: HFlowContainer = HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 12)
	group_box.add_child(row)
	return row

func _add_empty_build_line(text_value: String) -> void:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.68))
	build_content_list.add_child(label)

func _add_empty_build_line_to(parent: Control, text_value: String) -> void:
	var label: Label = Label.new()
	label.custom_minimum_size = Vector2(220, 72)
	label.text = text_value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.68))
	parent.add_child(label)

func _on_next_day_pressed() -> void:
	if next_day_button.disabled:
		return
	if _is_prep_map_hunger_low():
		_show_next_day_confirm_dialog()
		return
	_finish_next_day_entry()

# 响应饱食度不足确认点击事件，并执行进入下一天表现逻辑。
func _on_next_day_confirm_pressed() -> void:
	_hide_next_day_confirm_dialog()
	_finish_next_day_entry()

# 执行下一天入口表现，并扣除地图饱食度消耗。
func _finish_next_day_entry() -> void:
	_advance_facility_build_days()
	hunger = max(0, hunger - _get_prep_map_hunger_cost())
	_refresh_building_panel()
	_refresh_prep_all()
	_show_center_prompt(_text("next_day_ready"))

# 刷新准备界面all的界面显示或状态。
func _refresh_prep_all() -> void:
	_refresh_prep_equipment_slots()
	_refresh_prep_map_slot()
	_refresh_hunger_bar()
	_refresh_character_info()
	_refresh_map_info()
	if is_instance_valid(next_day_button):
		next_day_button.disabled = prep_map_item.is_empty()

# 刷新准备界面装备槽位的界面显示或状态。
func _refresh_prep_equipment_slots() -> void:
	_refresh_prep_equip_button(helmet_slot, "helmet")
	_refresh_prep_equip_button(armor_slot, "armor")
	_refresh_prep_equip_button(pants_slot, "pants")
	_refresh_prep_equip_button(shoes_slot, "shoes")
	_refresh_prep_equip_button(weapon_slot, "weapon")
	_refresh_prep_equip_button(accessory_slot, "accessory")
	_refresh_prep_equip_button(tool_1_slot, "tool_1")
	_refresh_prep_equip_button(tool_2_slot, "tool_2")

# 刷新准备界面装备按钮的界面显示或状态。
func _refresh_prep_equip_button(button: Button, slot_id: String) -> void:
	_clear_tooltip(button)
	if prep_equipment.has(slot_id):
		var item_data: Dictionary = prep_equipment[slot_id] as Dictionary
		button.text = _format_item_slot_text(item_data)
		button.modulate = _get_quality_color(item_data)
		_bind_tooltip(button, item_data)
	else:
		button.text = _get_equip_slot_name(slot_id)
		button.modulate = Color(0.75, 0.75, 0.75)

# 刷新准备界面地图槽位的界面显示或状态。
func _refresh_prep_map_slot() -> void:
	_clear_tooltip(prep_map_slot)
	map_warning_label.text = ""
	if prep_map_item.is_empty():
		prep_map_slot.text = _text("map_empty")
		prep_map_slot.modulate = Color(0.75, 0.75, 0.75)
	else:
		prep_map_slot.text = _format_prep_map_slot_text()
		prep_map_slot.modulate = _get_quality_color(prep_map_item)
		_bind_tooltip(prep_map_slot, prep_map_item)
		if _is_prep_map_hunger_low():
			map_warning_label.text = _text("map_hunger_warning") % _get_prep_map_debuff_text()

# 格式化明日地图槽位的核心信息文本。
func _format_prep_map_slot_text() -> String:
	var map_name: String = str(prep_map_item.get("name", "-"))
	var hunger_cost: int = _get_prep_map_hunger_cost()
	return "%s\n%s" % [map_name, _text("map_hunger_need") % hunger_cost]

# 刷新准备界面角色饱食度条。
func _refresh_hunger_bar() -> void:
	hunger_label.text = _text("hunger") % [hunger, max_hunger]
	hunger_bar.max_value = float(max_hunger)
	hunger_bar.value = float(hunger)

# 刷新角色信息的界面显示或状态。
func _refresh_character_info() -> void:
	for child in character_info_list.get_children():
		child.queue_free()
	_add_info_line(character_info_list, _text("character_info"), true)
	var props: Dictionary = {}
	for slot_id in PREP_EQUIP_SLOTS:
		if not prep_equipment.has(slot_id):
			continue
		var item_data: Dictionary = prep_equipment[slot_id] as Dictionary
		props = _merge_plain_props(props, item_data.get("props", {}))
	if props.is_empty():
		_add_info_line(character_info_list, "未装备", false)
		return
	for key in props.keys():
		_add_info_line(character_info_list, "%s：%s" % [str(key), str(props[key])], false)

# 刷新地图信息的界面显示或状态。
func _refresh_map_info() -> void:
	for child in map_info_list.get_children():
		child.queue_free()
	_add_info_line(map_info_list, _text("map_info"), true)
	if prep_map_item.is_empty():
		_add_info_line(map_info_list, _text("map_empty"), false)
		return
	_add_info_line(map_info_list, str(prep_map_item.get("name", "-")), false)
	_add_info_line(map_info_list, _text("map_hunger_need") % _get_prep_map_hunger_cost(), false)
	var props: Dictionary = prep_map_item.get("props", {}) as Dictionary
	for key in props.keys():
		_add_info_line(map_info_list, "%s：%s" % [str(key), str(props[key])], false)
	if _is_prep_map_hunger_low():
		_add_info_line(map_info_list, _text("map_hunger_warning") % _get_prep_map_debuff_text(), false)

# 向界面或数据中添加信息文本行。
func _add_info_line(parent: VBoxContainer, text_value: String, is_title: bool) -> void:
	var label: Label = Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_title:
		label.add_theme_font_size_override("font_size", 20)
	parent.add_child(label)

# 实现普通属性的界面或数据处理逻辑。
func _merge_plain_props(source_props: Dictionary, props_value: Variant) -> Dictionary:
	var result: Dictionary = source_props.duplicate(true)
	if not (props_value is Dictionary):
		return result
	var props: Dictionary = props_value as Dictionary
	for key in props.keys():
		if result.has(key) and result[key] is int and props[key] is int:
			result[key] += props[key]
		else:
			result[key] = props[key]
	return result

# 判断当前是否满足使用准备界面地图条件。
func _can_use_as_prep_map(item_data: Dictionary) -> bool:
	if str(item_data.get("map_category", "")) == MAP_BASE_CATEGORY:
		return true
	return str(item_data.get("category", "")) == CATEGORY_MAP and bool(item_data.get("is_base", false))

# 判断当前明日地图是否不满足饱食度需求。
func _is_prep_map_hunger_low() -> bool:
	if prep_map_item.is_empty():
		return false
	return hunger < _get_prep_map_hunger_cost()

# 获取当前明日地图的饱食度消耗。
func _get_prep_map_hunger_cost() -> int:
	if prep_map_item.is_empty():
		return 0
	return int(prep_map_item.get("hunger_cost", DEFAULT_MAP_HUNGER_COST))

# 获取当前明日地图饱食度不足时的Debuff文本。
func _get_prep_map_debuff_text() -> String:
	if prep_map_item.is_empty():
		return DEFAULT_MAP_HUNGER_DEBUFF
	return str(prep_map_item.get("hunger_debuff", DEFAULT_MAP_HUNGER_DEBUFF))

# 判断当前物品是否可以作为食物食用。
func _can_eat_food(item_data: Dictionary) -> bool:
	if str(item_data.get("category", "")) != CATEGORY_FOOD:
		return false
	if _get_item_count(item_data) <= 0:
		return false
	return int(item_data.get("food_value", 0)) > 0

# 食用背包中的食物并恢复饱食度。
func _eat_food_item(item_data: Dictionary) -> void:
	if hunger >= max_hunger:
		_show_center_prompt(_text("hunger_full"))
		return
	hunger = min(max_hunger, hunger + int(item_data.get("food_value", 0)))
	_take_item_from_inventory(item_data)
	_hide_tooltip()
	_refresh_prep_all()
	_refresh_inventory()

# 获取装备槽位标识数据。
func _get_equip_slot_id(item_data: Dictionary) -> String:
	var slot_id: String = str(item_data.get("equip_slot", ""))
	if PREP_EQUIP_SLOTS.has(slot_id):
		return slot_id
	return ""

# 获取装备槽位名称数据。
func _get_equip_slot_name(slot_id: String) -> String:
	match slot_id:
		"helmet":
			return _text("slot_helmet")
		"armor":
			return _text("slot_armor")
		"pants":
			return _text("slot_pants")
		"shoes":
			return _text("slot_shoes")
		"weapon":
			return _text("slot_weapon")
		"accessory":
			return _text("slot_accessory")
		"tool_1":
			return _text("slot_tool_1")
		"tool_2":
			return _text("slot_tool_2")
	return slot_id

# 刷新基底槽位的界面显示或状态。
func _refresh_base_slot() -> void:
	if base_item.is_empty():
		base_slot.text = _text("base_empty")
		base_slot.modulate = Color(0.75, 0.75, 0.75)
	else:
		base_slot.text = _format_item_slot_text(base_item)
		base_slot.modulate = _get_quality_color(base_item)
	upgrade_button.visible = false
	upgrade_button.disabled = true

# 刷新材料槽位的界面显示或状态。
func _refresh_material_slots() -> void:
	if not selected_blueprint.is_empty():
		_refresh_blueprint_material_slots()
		return
	var socket_count: int = _get_socket_count(base_item)
	var preview_index: int = material_items.size()
	if material_slot_buttons.size() != socket_count:
		_build_material_slots(socket_count)
	for i in range(material_slot_buttons.size()):
		var slot: Button = material_slot_buttons[i]
		_clear_tooltip(slot)
		if i < material_items.size():
			if i < _get_embedded_material_count():
				slot.text = "◆ %s" % _format_item_slot_text(material_items[i])
			else:
				slot.text = _format_item_slot_text(material_items[i])
			slot.modulate = _get_quality_color(material_items[i])
			_bind_tooltip(slot, material_items[i])
		elif _has_material_preview() and i == preview_index:
			slot.text = "%s\n%s" % [_text("previewing"), str(preview_material_item.get("name", "-"))]
			slot.modulate = Color(0.55, 0.75, 1.0)
			_bind_tooltip(slot, preview_material_item)
		else:
			slot.text = _text("socket_empty")
			slot.modulate = Color(0.75, 0.75, 0.75)
			_clear_tooltip(slot)

# 刷新结果列表的界面显示或状态。
func _refresh_result_list() -> void:
	for child in base_result_list.get_children():
		child.queue_free()
	var lines: Array = _get_result_lines()
	if lines.is_empty():
		_add_result_line(_text("result_empty"), false)
		return
	for line in lines:
		_add_result_line(str(line), false)

# 刷新左侧合成蓝图列表。
func _refresh_blueprint_list() -> void:
	for child in result_list.get_children():
		child.queue_free()
	if blueprint_recipes.is_empty():
		_add_blueprint_header(_text("blueprint_empty"))
		return
	var category_names: Array = []
	for recipe in blueprint_recipes:
		var recipe_data: Dictionary = recipe as Dictionary
		var category_name: String = str(recipe_data.get("category", "其他"))
		if not category_names.has(category_name):
			category_names.append(category_name)
	for category_name in category_names:
		_add_blueprint_category(category_name)
		for recipe in blueprint_recipes:
			var recipe_data: Dictionary = recipe as Dictionary
			if str(recipe_data.get("category", "其他")) != category_name:
				continue
			var button: Button = _make_blueprint_button(recipe_data)
			result_list.add_child(button)

# 添加蓝图列表标题。
func _add_blueprint_header(text_value: String) -> void:
	var label: Label = Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	result_list.add_child(label)

# 添加蓝图分类标题。
func _add_blueprint_category(category_name: String) -> void:
	var label: Label = Label.new()
	label.text = category_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.72, 0.86, 1.0))
	result_list.add_child(label)

# 创建一个蓝图按钮。
func _make_blueprint_button(recipe_data: Dictionary) -> Button:
	var button: Button = Button.new()
	var recipe_name: String = str(recipe_data.get("name", "-"))
	var can_make: bool = _has_blueprint_requirements(recipe_data)
	var is_selected: bool = str(selected_blueprint.get("id", "")) == str(recipe_data.get("id", ""))
	button.text = recipe_name
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.custom_minimum_size = Vector2(0, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if can_make:
		_apply_button_style(button, Color(0.14, 0.27, 0.18), Color(0.34, 0.68, 0.36), Color(0.20, 0.36, 0.22), Color(0.12, 0.14, 0.12))
	else:
		_apply_button_style(button, Color(0.28, 0.15, 0.15), Color(0.70, 0.28, 0.24), Color(0.36, 0.19, 0.18), Color(0.14, 0.11, 0.11))
	if is_selected:
		button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	button.pressed.connect(_on_blueprint_pressed.bind(recipe_data))
	return button

# 响应蓝图点击事件，并自动填充基底预览和材料需求。
func _on_blueprint_pressed(recipe_data: Dictionary) -> void:
	clear_workbench()
	selected_blueprint = recipe_data.duplicate(true)
	var result_item: Dictionary = _get_blueprint_result(selected_blueprint)
	base_item = result_item
	base_item["count"] = 1
	base_has_pending_changes = true
	_refresh_all()

# 刷新蓝图需求材料槽位。
func _refresh_blueprint_material_slots() -> void:
	var requirements: Array = _get_blueprint_requirements(selected_blueprint)
	if material_slot_buttons.size() != requirements.size():
		_build_material_slots(requirements.size())
	for i in range(material_slot_buttons.size()):
		var slot: Button = material_slot_buttons[i]
		_clear_tooltip(slot)
		if i >= requirements.size():
			slot.text = ""
			slot.disabled = true
			continue
		var requirement: Dictionary = requirements[i] as Dictionary
		var item_id: String = str(requirement.get("id", ""))
		var item_name: String = str(requirement.get("name", item_id))
		var need_count: int = int(requirement.get("count", 0))
		var have_count: int = _get_inventory_count_by_id(item_id)
		var is_enough: bool = have_count >= need_count
		slot.text = "%s\n%d/%d" % [item_name, have_count, need_count]
		slot.disabled = true
		if is_enough:
			_apply_button_style(slot, Color(0.13, 0.28, 0.15), Color(0.30, 0.74, 0.33), Color(0.18, 0.34, 0.18), Color(0.13, 0.28, 0.15))
			slot.add_theme_color_override("font_color", Color(0.62, 1.0, 0.55))
			slot.add_theme_color_override("font_disabled_color", Color(0.62, 1.0, 0.55))
		else:
			_apply_button_style(slot, Color(0.32, 0.12, 0.12), Color(0.86, 0.24, 0.20), Color(0.40, 0.15, 0.15), Color(0.32, 0.12, 0.12))
			slot.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
			slot.add_theme_color_override("font_disabled_color", Color(1.0, 0.42, 0.36))

# 执行当前选中蓝图的合成消耗和成品生成。
func _craft_selected_blueprint() -> void:
	if selected_blueprint.is_empty():
		return
	if not _has_blueprint_requirements(selected_blueprint):
		return
	_consume_blueprint_requirements(selected_blueprint)
	base_item = _get_blueprint_result(selected_blueprint)
	base_item["count"] = 1
	_ensure_base_socket_state(base_item)
	material_items = _get_embedded_materials(base_item)
	base_has_pending_changes = false
	base_is_new_craft_result = true
	selected_blueprint.clear()
	_set_status(_text("status_crafted"))
	_refresh_all()

# 刷新背包的界面显示或状态。
func _refresh_inventory() -> void:
	for child in inventory_grid.get_children():
		child.queue_free()
	for item in inventory_items:
		if _get_item_count(item) <= 0:
			continue
		if not _is_item_in_category(item, current_category):
			continue
		var slot: Button = _make_slot_button(_format_item_slot_text(item), true)
		slot.modulate = _get_quality_color(item)
		slot.pressed.connect(_on_inventory_slot_pressed.bind(item))
		slot.gui_input.connect(_on_inventory_slot_gui_input.bind(item))
		slot.mouse_entered.connect(_mark_inventory_item_read.bind(item))
		_bind_tooltip(slot, item)
		slot.mouse_entered.connect(_show_material_preview.bind(item))
		slot.mouse_exited.connect(_hide_material_preview)
		inventory_grid.add_child(slot)
		if bool((item as Dictionary).get("is_unread", false)):
			_add_unread_dot(slot)

# 响应背包槽位输入事件，并处理右键食用食物。
func _on_inventory_slot_gui_input(event: InputEvent, item_data: Dictionary) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if not _can_eat_food(item_data):
		return
	_show_food_menu(item_data, mouse_event.global_position)
	inventory_grid.accept_event()

# 响应整理背包点击事件，并合并与排序背包物品。
func _on_sort_inventory_pressed() -> void:
	_merge_inventory_items()
	inventory_items.sort_custom(_sort_inventory_items)
	_refresh_inventory()

# 将背包物品标记为已读并清除红点。
func _mark_inventory_item_read(item_data: Dictionary) -> void:
	if not bool(item_data.get("is_unread", false)):
		return
	item_data["is_unread"] = false
	_refresh_inventory()

# 为未读背包物品添加红点标记。
func _add_unread_dot(slot: Button) -> void:
	var dot: Panel = Panel.new()
	var dot_style: StyleBoxFlat = StyleBoxFlat.new()
	dot_style.bg_color = Color(1.0, 0.12, 0.08)
	dot_style.corner_radius_top_left = 8
	dot_style.corner_radius_top_right = 8
	dot_style.corner_radius_bottom_left = 8
	dot_style.corner_radius_bottom_right = 8
	dot.add_theme_stylebox_override("panel", dot_style)
	dot.custom_minimum_size = Vector2(10, 10)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -14.0
	dot.offset_top = 4.0
	dot.offset_right = -4.0
	dot.offset_bottom = 14.0
	slot.add_child(dot)

# 显示食物右键操作菜单。
func _show_food_menu(item_data: Dictionary, menu_position: Vector2) -> void:
	pending_food_item = item_data
	food_menu.clear()
	food_menu.add_item(_text("eat"), 0)
	food_menu.position = Vector2i(int(menu_position.x), int(menu_position.y))
	food_menu.popup()

# 响应食物右键菜单点击事件，并执行食用逻辑。
func _on_food_menu_id_pressed(id: int) -> void:
	if id != 0:
		return
	if pending_food_item.is_empty():
		return
	_eat_food_item(pending_food_item)
	pending_food_item.clear()

# 刷新分类页签的界面显示或状态。
func _refresh_tabs() -> void:
	for tab_id in tab_buttons.keys():
		var button: Button = tab_buttons[tab_id] as Button
		if not button:
			continue
		button.button_pressed = tab_id == current_category

# 刷新合成按钮的界面显示或状态。
func _update_craft_button() -> void:
	craft_button.disabled = not _can_craft()
	if not selected_blueprint.is_empty():
		return
	if base_item.is_empty():
		_set_status(_text("status_select_base"))
	elif _get_socket_count(base_item) <= 0:
		_set_status(_text("status_no_socket"))
	elif not base_has_pending_changes:
		_set_status(_text("status_need_material"))
	elif _can_craft():
		_set_status(_text("status_ready"))

# 显示材料窗口，并设置相关临时状态。
func _show_remove_material_dialog(slot_index: int) -> void:
	pending_remove_material_index = slot_index
	remove_material_title.text = _text("remove_material_title")
	remove_material_overlay.visible = true

# 隐藏材料窗口，并清理相关临时状态。
func _hide_remove_material_dialog() -> void:
	pending_remove_material_index = -1
	remove_material_overlay.visible = false

# 显示饱食度不足的下一天确认窗口。
func _show_next_day_confirm_dialog() -> void:
	next_day_confirm_desc.text = _text("next_day_hunger_confirm") % _get_prep_map_debuff_text()
	next_day_confirm_overlay.visible = true

# 隐藏饱食度不足的下一天确认窗口。
func _hide_next_day_confirm_dialog() -> void:
	next_day_confirm_overlay.visible = false

# 显示升级窗口，并设置相关临时状态。
func _show_upgrade_dialog() -> void:
	pending_upgrade_item_index = -1
	upgrade_overlay.visible = true
	_refresh_upgrade_dialog()

# 隐藏升级窗口，并清理相关临时状态。
func _hide_upgrade_dialog() -> void:
	pending_upgrade_item_index = -1
	upgrade_overlay.visible = false

# 刷新升级窗口的界面显示或状态。
func _refresh_upgrade_dialog() -> void:
	for child in upgrade_cost_row.get_children():
		child.queue_free()
	upgrade_candidate_buttons.clear()
	var candidate_indexes: Array[int] = _get_upgrade_candidate_indexes()
	for candidate_index in candidate_indexes:
		var item_data: Dictionary = inventory_items[candidate_index] as Dictionary
		var button: Button = _make_slot_button(_format_item_slot_text(item_data), true)
		button.modulate = Color(1.0, 0.9, 0.45) if candidate_index == pending_upgrade_item_index else _get_quality_color(item_data)
		button.pressed.connect(_on_upgrade_candidate_pressed.bind(candidate_index))
		_bind_tooltip(button, item_data)
		upgrade_cost_row.add_child(button)
		upgrade_candidate_buttons.append(button)
	upgrade_confirm_button.disabled = pending_upgrade_item_index < 0

# 响应升级候选物品点击事件，并执行对应界面逻辑。
func _on_upgrade_candidate_pressed(candidate_index: int) -> void:
	pending_upgrade_item_index = candidate_index
	_refresh_upgrade_dialog()

# 实现卡包商品的界面或数据处理逻辑。
# 重建商店翻牌数据，每一行保存自己的暗牌、翻牌次数和刷新状态。
func _rebuild_flip_rows() -> void:
	flip_rows.clear()
	for row_id_value in FLIP_CARD_ROWS:
		var row_id: String = str(row_id_value)
		flip_rows[row_id] = {
			"cards": [],
			"flip_count": 0,
			"refreshed": false
		}
		_reset_flip_row_cards(row_id)
	flip_next_day_requested = false
	card_tool_mode = CARD_TOOL_NONE

# 重新生成指定翻牌行的三张暗牌。
func _reset_flip_row_cards(row_id: String) -> void:
	if not flip_rows.has(row_id):
		return
	var cards: Array = []
	for index in range(FLIP_CARD_COLS):
		var item_data: Dictionary = _roll_flip_card_item(row_id, index)
		cards.append({
			"item": item_data,
			"is_open": false,
			"is_deleted": false
		})
	var row_data: Dictionary = flip_rows[row_id] as Dictionary
	row_data["cards"] = cards
	row_data["flip_count"] = 0

# 从配置表中抽取当前翻牌行可使用的物品数据。
func _roll_flip_card_item(row_id: String, index: int) -> Dictionary:
	var source_items: Array = _get_flip_row_source_items(row_id)
	if source_items.is_empty():
		return _make_fallback_flip_card_item(row_id, index)
	var source_index: int = rng.randi_range(0, source_items.size() - 1)
	var source_item: Dictionary = source_items[source_index] as Dictionary
	var item_data: Dictionary = source_item.duplicate(true)
	item_data["count"] = 1
	item_data["instance_id"] = ""
	return item_data

# 获取翻牌行对应的配置物品列表。
func _get_flip_row_source_items(row_id: String) -> Array:
	var result: Array = []
	var categories_value: Variant = FLIP_ROW_SOURCE_CATEGORIES.get(row_id, [])
	var categories: Array = categories_value as Array
	for item_value in map_element_items:
		if not (item_value is Dictionary):
			continue
		var item_data: Dictionary = item_value as Dictionary
		var map_category: String = str(item_data.get("map_category", ""))
		if categories.has(map_category):
			result.append(item_data)
	return result

# 在配置表暂时没有对应行数据时生成占位卡，保证界面可以调试。
func _make_fallback_flip_card_item(row_id: String, index: int) -> Dictionary:
	var row_name: String = str(FLIP_ROW_NAMES.get(row_id, "卡牌"))
	var quality: String = "common"
	if row_id == FLIP_ROW_GOD and index == 1:
		quality = "rare"
	var item_data: Dictionary = {
		"id": "%s_fallback_%d" % [row_id, index],
		"name": "%s%d" % [row_name, index + 1],
		"category": CATEGORY_MAP,
		"map_category": row_id,
		"quality": quality,
		"count": 1,
		"description": "临时翻牌调试数据，后续可由配置表替换。",
		"props": {}
	}
	return item_data

# 刷新翻牌商店界面控件。
func _refresh_flip_cards() -> void:
	if not is_instance_valid(card_rows_container):
		return
	if flip_rows.is_empty():
		_rebuild_flip_rows()
	for child in card_rows_container.get_children():
		child.queue_free()
	for row_id_value in FLIP_CARD_ROWS:
		var row_id: String = str(row_id_value)
		var row_box: HBoxContainer = _make_flip_row_control(row_id)
		card_rows_container.add_child(row_box)
	_refresh_flip_action_bar()

# 生成单行翻牌控件，包含标题、三张牌和刷新按钮。
func _make_flip_row_control(row_id: String) -> HBoxContainer:
	var row_box: HBoxContainer = HBoxContainer.new()
	row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_box.custom_minimum_size = Vector2(0, 118)
	row_box.add_theme_constant_override("separation", 12)
	var title: Label = Label.new()
	title.custom_minimum_size = Vector2(96, 0)
	title.text = str(FLIP_ROW_NAMES.get(row_id, row_id))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	row_box.add_child(title)
	var row_data: Dictionary = flip_rows.get(row_id, {}) as Dictionary
	var cards: Array = row_data.get("cards", []) as Array
	for index in range(cards.size()):
		var card_data: Dictionary = cards[index] as Dictionary
		var button: Button = _make_flip_card_button(row_id, index, card_data)
		row_box.add_child(button)
	var refresh_button: Button = Button.new()
	refresh_button.custom_minimum_size = Vector2(120, 92)
	refresh_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	refresh_button.focus_mode = Control.FOCUS_NONE
	var refreshed: bool = bool(row_data.get("refreshed", false))
	refresh_button.disabled = refreshed
	refresh_button.text = "已刷新" if refreshed else "刷新：%d" % _get_flip_refresh_cost(row_id)
	refresh_button.pressed.connect(_on_flip_refresh_pressed.bind(row_id, refresh_button))
	_apply_button_style(refresh_button, Color(0.13, 0.20, 0.24), Color(0.42, 0.62, 0.72), Color(0.20, 0.32, 0.38), Color(0.12, 0.12, 0.12))
	row_box.add_child(refresh_button)
	return row_box

# 生成单张翻牌按钮并绑定交互。
func _make_flip_card_button(row_id: String, index: int, card_data: Dictionary) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(170, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	var is_open: bool = bool(card_data.get("is_open", false))
	var is_deleted: bool = bool(card_data.get("is_deleted", false))
	if is_deleted:
		button.text = "已删除"
		button.disabled = true
	elif is_open:
		var item_data: Dictionary = card_data.get("item", {}) as Dictionary
		button.text = "%s\n%s" % [str(item_data.get("name", "-")), _get_quality_name(str(item_data.get("quality", "common")))]
		button.modulate = _get_quality_color(item_data)
		_bind_tooltip(button, item_data)
	else:
		button.text = "？\n未翻开"
	button.pressed.connect(_on_flip_card_pressed.bind(row_id, index, button))
	button.gui_input.connect(_on_flip_card_gui_input.bind(row_id, index))
	_apply_button_style(button, Color(0.11, 0.13, 0.16), Color(0.48, 0.42, 0.30), Color(0.18, 0.21, 0.25), Color(0.10, 0.10, 0.10))
	return button

# 刷新底部开始下一天和道具按钮的状态。
func _refresh_flip_action_bar() -> void:
	if is_instance_valid(flip_start_next_day_button):
		flip_start_next_day_button.disabled = not _has_open_map_card()
		flip_start_next_day_button.text = "开始下一天"
	if is_instance_valid(delete_tool_button):
		delete_tool_button.text = "删除：%d" % delete_tool_count
		delete_tool_button.disabled = delete_tool_count <= 0
		_apply_tool_mode_button_style(delete_tool_button, card_tool_mode == CARD_TOOL_DELETE)
	if is_instance_valid(upgrade_tool_button):
		upgrade_tool_button.text = "升级：%d" % upgrade_tool_count
		upgrade_tool_button.disabled = upgrade_tool_count <= 0
		_apply_tool_mode_button_style(upgrade_tool_button, card_tool_mode == CARD_TOOL_UPGRADE)

# 根据是否处于道具模式刷新按钮颜色。
func _apply_tool_mode_button_style(button: Button, selected: bool) -> void:
	if selected:
		_apply_button_style(button, Color(0.22, 0.36, 0.24), Color(0.56, 0.82, 0.38), Color(0.28, 0.44, 0.28), Color(0.10, 0.10, 0.10))
	else:
		_apply_button_style(button, Color(0.16, 0.16, 0.18), Color(0.42, 0.42, 0.48), Color(0.24, 0.24, 0.28), Color(0.10, 0.10, 0.10))

# 响应翻牌按钮点击，普通模式翻开暗牌，道具模式执行删除或升级。
func _on_flip_card_pressed(row_id: String, index: int, source_button: Control) -> void:
	var card_data: Dictionary = _get_flip_card_data(row_id, index)
	if card_data.is_empty():
		return
	if card_tool_mode == CARD_TOOL_DELETE:
		_try_delete_flip_card(row_id, index)
		return
	if card_tool_mode == CARD_TOOL_UPGRADE:
		_try_upgrade_flip_card(row_id, index)
		return
	if bool(card_data.get("is_open", false)) or bool(card_data.get("is_deleted", false)):
		return
	var price: int = _get_flip_cost(row_id)
	gold -= price
	if price > 0:
		_play_gold_cost_fly_text(source_button, price)
	card_data["is_open"] = true
	var row_data: Dictionary = flip_rows[row_id] as Dictionary
	row_data["flip_count"] = int(row_data.get("flip_count", 0)) + 1
	_update_gold_label()
	_refresh_flip_cards()

# 响应翻牌按钮右键输入，用于退出删除或升级状态。
func _on_flip_card_gui_input(event: InputEvent, _row_id: String, _index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			card_tool_mode = CARD_TOOL_NONE
			_refresh_flip_action_bar()
			get_viewport().set_input_as_handled()

# 响应商店面板右键输入，用于退出删除或升级状态。
func _on_store_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			card_tool_mode = CARD_TOOL_NONE
			_refresh_flip_action_bar()

# 响应整行刷新按钮点击，按本行已翻开数量计算费用。
func _on_flip_refresh_pressed(row_id: String, source_button: Control) -> void:
	if not flip_rows.has(row_id):
		return
	var row_data: Dictionary = flip_rows[row_id] as Dictionary
	if bool(row_data.get("refreshed", false)):
		_show_center_prompt("本行已经刷新过。")
		return
	var price: int = _get_flip_refresh_cost(row_id)
	row_data["refreshed"] = true
	gold -= price
	_play_gold_cost_fly_text(source_button, price)
	_reset_flip_row_cards(row_id)
	_update_gold_label()
	_refresh_flip_cards()

# 响应删除道具按钮点击，进入或退出删除状态。
func _on_delete_tool_pressed() -> void:
	if delete_tool_count <= 0:
		return
	card_tool_mode = CARD_TOOL_NONE if card_tool_mode == CARD_TOOL_DELETE else CARD_TOOL_DELETE
	_refresh_flip_action_bar()

# 响应升级道具按钮点击，进入或退出升级状态。
func _on_upgrade_tool_pressed() -> void:
	if upgrade_tool_count <= 0:
		return
	card_tool_mode = CARD_TOOL_NONE if card_tool_mode == CARD_TOOL_UPGRADE else CARD_TOOL_UPGRADE
	_refresh_flip_action_bar()

# 删除一张已经翻开的卡牌。
func _try_delete_flip_card(row_id: String, index: int) -> void:
	var card_data: Dictionary = _get_flip_card_data(row_id, index)
	if card_data.is_empty() or not bool(card_data.get("is_open", false)) or bool(card_data.get("is_deleted", false)):
		_show_center_prompt("没有可删除的翻开卡。")
		return
	delete_tool_count -= 1
	card_data["is_deleted"] = true
	card_data["is_open"] = false
	card_tool_mode = CARD_TOOL_NONE
	_refresh_flip_cards()

# 将一张已经翻开的卡牌提升到更高品质。
func _try_upgrade_flip_card(row_id: String, index: int) -> void:
	var card_data: Dictionary = _get_flip_card_data(row_id, index)
	if card_data.is_empty() or not bool(card_data.get("is_open", false)) or bool(card_data.get("is_deleted", false)):
		_show_center_prompt("没有可升级的翻开卡。")
		return
	var item_data: Dictionary = card_data.get("item", {}) as Dictionary
	var current_quality: String = str(item_data.get("quality", "common"))
	var next_quality: String = str(FLIP_QUALITY_UPGRADE.get(current_quality, current_quality))
	if next_quality == current_quality:
		_show_center_prompt("该卡牌已经是最高品质。")
		return
	item_data["quality"] = next_quality
	item_data["description"] = "%s\n已通过天赋道具升级。" % str(item_data.get("description", ""))
	card_data["item"] = item_data
	upgrade_tool_count -= 1
	card_tool_mode = CARD_TOOL_NONE
	_refresh_flip_cards()

# 响应开始下一天按钮点击，当前只记录状态并显示提示，后续再接入回合流程。
func _on_flip_start_next_day_pressed() -> void:
	if not _has_open_map_card():
		_show_center_prompt("必须先翻开至少一张地图牌。")
		return
	if not flip_next_day_requested:
		_advance_facility_build_days()
	flip_next_day_requested = true
	_refresh_building_panel()
	_show_center_prompt("下一天选择已确认，后续接入回合流程。")

# 读取指定位置的翻牌数据。
func _get_flip_card_data(row_id: String, index: int) -> Dictionary:
	if not flip_rows.has(row_id):
		return {}
	var row_data: Dictionary = flip_rows[row_id] as Dictionary
	var cards: Array = row_data.get("cards", []) as Array
	if index < 0 or index >= cards.size():
		return {}
	return cards[index] as Dictionary

# 计算翻开下一张卡牌需要消耗的金币。
func _get_flip_cost(row_id: String) -> int:
	var row_data: Dictionary = flip_rows.get(row_id, {}) as Dictionary
	var flip_count: int = int(row_data.get("flip_count", 0))
	var free_count: int = 0 if row_id == FLIP_ROW_GOD else 1
	if flip_count < free_count:
		return 0
	var paid_index: int = flip_count - free_count
	return FLIP_BASE_PRICE * int(pow(2.0, float(paid_index)))

# 计算刷新当前行需要消耗的金币。
func _get_flip_refresh_cost(row_id: String) -> int:
	var opened_count: int = _get_open_flip_card_count(row_id)
	return FLIP_REFRESH_BASE_PRICE * int(pow(2.0, float(opened_count)))

# 统计某一行已经翻开且未删除的卡牌数量。
func _get_open_flip_card_count(row_id: String) -> int:
	if not flip_rows.has(row_id):
		return 0
	var row_data: Dictionary = flip_rows[row_id] as Dictionary
	var cards: Array = row_data.get("cards", []) as Array
	var opened_count: int = 0
	for card_value in cards:
		var card_data: Dictionary = card_value as Dictionary
		if bool(card_data.get("is_open", false)) and not bool(card_data.get("is_deleted", false)):
			opened_count += 1
	return opened_count

# 判断地图牌是否已经至少翻开一张。
func _has_open_map_card() -> bool:
	return _get_open_flip_card_count(FLIP_ROW_MAP) > 0

# 将品质英文配置转换为界面可读文本。
func _get_quality_name(quality: String) -> String:
	match quality:
		"legendary":
			return "传说"
		"epic":
			return "史诗"
		"rare":
			return "稀有"
		_:
			return "普通"

# 保留旧卡包商品数据构建逻辑，方便后续需要回收概率配置时复用。
func _rebuild_pack_products() -> void:
	map_pack_products.clear()
	for category in MAP_PACK_ORDER:
		var entries: Array = _get_pack_entries_for_category(category)
		if entries.is_empty():
			continue
		map_pack_products.append({
			"id": "%s_pack" % category,
			"category": category,
			"name": str(MAP_CATEGORY_NAMES.get(category, "%s卡包" % category)),
			"price": _get_pack_price(category, entries),
			"stock": DEFAULT_PACK_STOCK,
			"entries": entries
		})

# 获取卡包条目for分类数据。
func _get_pack_entries_for_category(category: String) -> Array:
	var entries: Array = []
	for item in map_element_items:
		if str(item.get("map_category", "")) != category:
			continue
		var weight: float = float(item.get("pack_probability", 0.0))
		if weight <= 0.0:
			weight = float(PACK_QUALITY_WEIGHT.get(str(item.get("quality", "common")), 50))
		if weight <= 0.0:
			continue
		entries.append({"item": item, "weight": weight})
	return entries

# 获取卡包价格数据。
func _get_pack_price(category: String, entries: Array) -> int:
	var max_quality_price: int = DEFAULT_PACK_PRICE
	for entry in entries:
		var item: Dictionary = entry.get("item", {}) as Dictionary
		match str(item.get("quality", "common")):
			"rare":
				max_quality_price = max(max_quality_price, 14)
			"epic":
				max_quality_price = max(max_quality_price, 18)
			"legendary":
				max_quality_price = max(max_quality_price, 24)
	if category == "hazard":
		max_quality_price += 2
	return max_quality_price

# 刷新卡包商品的界面显示或状态。
func _refresh_pack_products() -> void:
	_refresh_flip_cards()

# 生成卡包按钮所需的数据或控件。
func _make_pack_button(pack_data: Dictionary) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(150, 170)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	var pack_name: String = str(pack_data.get("name", "-"))
	var stock: int = int(pack_data.get("stock", 0))
	if stock <= 0:
		button.text = "%s%s" % [pack_name, _text("pack_sold_out")]
		button.disabled = true
	else:
		button.text = "%s\n%s\n%s" % [
			pack_name,
			_text("pack_price") % int(pack_data.get("price", DEFAULT_PACK_PRICE)),
			_text("pack_stock") % stock
		]
	button.pressed.connect(_on_pack_pressed.bind(pack_data, button))
	button.mouse_entered.connect(_show_pack_tooltip.bind(button, pack_data))
	button.mouse_exited.connect(_hide_tooltip)
	return button

# 显示卡包tooltip，并设置相关临时状态。
func _show_pack_tooltip(slot: Control, pack_data: Dictionary) -> void:
	var entries: Array = pack_data.get("entries", [])
	_set_tooltip_line_limits(2, max(64, entries.size() + 4))
	tooltip_name.text = str(pack_data.get("name", "-"))
	tooltip_type.text = "%s / %s" % [_text("pack_price") % int(pack_data.get("price", DEFAULT_PACK_PRICE)), _text("pack_stock") % int(pack_data.get("stock", 0))]
	tooltip_desc.text = "购买后随机开出 %d 个地图元素。" % PACK_DRAW_COUNT
	tooltip_props.text = _get_pack_probability_text(pack_data)
	_apply_tooltip_content_size(PACK_TOOLTIP_MAX_SIZE)
	tooltip_panel.visible = true
	await get_tree().process_frame
	if not is_instance_valid(slot):
		return
	_place_pack_tooltip(slot, Rect2(Vector2.ZERO, get_viewport_rect().size), PACK_TOOLTIP_MAX_SIZE)

# 获取卡包概率文本数据。
func _get_pack_probability_text(pack_data: Dictionary) -> String:
	var entries: Array = pack_data.get("entries", [])
	var total_weight: float = 0.0
	for entry in entries:
		total_weight += float(entry.get("weight", 0.0))
	if total_weight <= 0.0:
		return ""
	var lines: Array[String] = []
	for entry in entries:
		var item: Dictionary = entry.get("item", {}) as Dictionary
		var item_id: String = str(item.get("id", ""))
		var name: String = str(item.get("name", "-")) if discovered_map_element_ids.has(item_id) else "？？？"
		var chance: float = float(entry.get("weight", 0.0)) / total_weight * 100.0
		lines.append(_text("pack_detail_unknown") % [name, "%.1f%%" % chance])
	return "\n".join(lines)

# 实现卡包的界面或数据处理逻辑。
func _open_pack(pack_data: Dictionary) -> Array:
	var rewards: Array = []
	var entries: Array = pack_data.get("entries", [])
	for i in range(PACK_DRAW_COUNT):
		var item: Dictionary = _roll_pack_item(entries)
		if item.is_empty():
			continue
		var reward: Dictionary = item.duplicate(true)
		reward["count"] = 1
		reward["instance_id"] = ""
		rewards.append(reward)
		discovered_map_element_ids[str(reward.get("id", ""))] = true
	return rewards

# 实现卡包物品的界面或数据处理逻辑。
func _roll_pack_item(entries: Array) -> Dictionary:
	var total_weight: float = 0.0
	for entry in entries:
		total_weight += float(entry.get("weight", 0.0))
	if total_weight <= 0.0:
		return {}
	var target: float = rng.randf_range(0.0, total_weight)
	var cursor: float = 0.0
	for entry in entries:
		cursor += float(entry.get("weight", 0.0))
		if target <= cursor:
			var item: Dictionary = entry.get("item", {}) as Dictionary
			return item
	return {}

# 显示卡包弹窗，并设置相关临时状态。
func _show_open_pack_overlay(rewards: Array) -> void:
	for child in open_pack_result_grid.get_children():
		child.queue_free()
	var sorted_rewards: Array = rewards.duplicate()
	sorted_rewards.sort_custom(_sort_items_by_name)
	for item in sorted_rewards:
		var slot: Button = _make_slot_button(_format_item_slot_text(item), true)
		slot.modulate = _get_quality_color(item)
		slot.pressed.connect(_close_open_pack_overlay)
		_bind_tooltip(slot, item)
		open_pack_result_grid.add_child(slot)
	open_pack_overlay.visible = true

# 实现物品by名称的界面或数据处理逻辑。
func _sort_items_by_name(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("name", "")) < str(b.get("name", ""))

# 隐藏卡包弹窗，并清理相关临时状态。
func _close_open_pack_overlay() -> void:
	add_new_inventory_items(pending_open_pack_items)
	pending_open_pack_items.clear()
	open_pack_overlay.visible = false
	_hide_tooltip()
	_refresh_all()

# 实现金币cost飞字文本的界面或数据处理逻辑。
func _play_gold_cost_fly_text(source: Control, price: int) -> void:
	var label: Label = Label.new()
	label.text = "-%d" % price
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = Color(1.0, 0.35, 0.2)
	fly_text_layer.add_child(label)
	label.global_position = source.global_position + source.size * 0.5
	var target_label: Label = _get_active_gold_label()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", target_label.global_position + target_label.size * 0.5, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(label.queue_free)

# 显示居中提示，并设置相关临时状态。
func _show_center_prompt(text_value: String) -> void:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color(1.0, 0.82, 0.35)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(520, 36)
	fly_text_layer.add_child(label)
	var viewport_size: Vector2 = get_viewport_rect().size
	label.global_position = viewport_size * 0.5 - label.custom_minimum_size * 0.5
	var tween: Tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(label.queue_free)

# 刷新金币label的界面显示或状态。
func _update_gold_label() -> void:
	if is_instance_valid(gold_label):
		gold_label.text = _text("gold") % gold
	if is_instance_valid(prep_gold_label):
		prep_gold_label.text = _text("gold") % gold
	if is_instance_valid(shop_gold_label):
		shop_gold_label.text = _text("gold") % gold

# 获取当前界面应该使用的金币显示栏。
func _get_active_gold_label() -> Label:
	if current_mode == MODE_PREP and is_instance_valid(prep_gold_label):
		return prep_gold_label
	if current_mode == MODE_SHOP and is_instance_valid(shop_gold_label):
		return shop_gold_label
	return gold_label

# 实现物品to基底的界面或数据处理逻辑。
func _move_item_to_base(item_data: Dictionary) -> void:
	_take_item_from_inventory(item_data)
	base_item = item_data.duplicate(true)
	base_item["count"] = 1
	_ensure_base_socket_state(base_item)
	material_items = _get_embedded_materials(base_item)
	base_has_pending_changes = false
	base_is_new_craft_result = false
	item_added_to_table.emit(base_item)
	_refresh_all()

# 实现基底物品的界面或数据处理逻辑。
func _replace_base_item(item_data: Dictionary) -> void:
	_prepare_base_for_return()
	if not base_item.is_empty():
		if base_is_new_craft_result:
			_add_new_item_to_inventory(base_item)
		else:
			_return_item_to_inventory(base_item)
		item_removed_from_table.emit(base_item)
	base_item.clear()
	material_items.clear()
	base_has_pending_changes = false
	base_is_new_craft_result = false
	_move_item_to_base(item_data)

# 向界面或数据中添加材料。
func _add_material(item_data: Dictionary) -> void:
	_hide_material_preview()
	if material_items.size() >= _get_socket_count(base_item):
		_set_status(_text("status_no_slot"))
		return
	_take_item_from_inventory(item_data)
	var table_item: Dictionary = item_data.duplicate(true)
	table_item["count"] = 1
	material_items.append(table_item)
	base_has_pending_changes = true
	item_added_to_table.emit(table_item)
	_refresh_all()

# 从界面或数据中移除临时材料。
func _remove_pending_material(index: int) -> void:
	if index < 0 or index >= material_items.size():
		return
	var item_data: Dictionary = material_items[index]
	material_items.remove_at(index)
	_return_item_to_inventory(item_data)
	item_removed_from_table.emit(item_data)
	base_has_pending_changes = material_items.size() > _get_embedded_material_count()
	_refresh_all()

# 显示材料预览，并设置相关临时状态。
func _show_material_preview(item_data: Dictionary) -> void:
	if not _can_preview_material(item_data):
		return
	preview_material_item = item_data.duplicate(true)
	preview_material_item["count"] = 1
	_refresh_material_slots()
	_refresh_result_list()

# 隐藏材料预览，并清理相关临时状态。
func _hide_material_preview() -> void:
	if preview_material_item.is_empty():
		return
	preview_material_item.clear()
	_refresh_material_slots()
	_refresh_result_list()

# 实现has材料预览的界面或数据处理逻辑。
func _has_material_preview() -> bool:
	return not preview_material_item.is_empty()

# 判断当前是否满足预览材料条件。
func _can_preview_material(item_data: Dictionary) -> bool:
	if current_mode != MODE_CRAFT:
		return false
	if not selected_blueprint.is_empty():
		return false
	if base_item.is_empty():
		return false
	if material_items.size() >= _get_socket_count(base_item):
		return false
	return _can_use_as_material(item_data)

# 获取预览材料物品数据。
func _get_preview_material_items() -> Array:
	var preview_materials: Array = _duplicate_item_array(material_items)
	if _has_material_preview():
		preview_materials.append(preview_material_item.duplicate(true))
	return preview_materials

# 判断当前是否满足使用基底条件。
func _can_use_as_base(item_data: Dictionary) -> bool:
	if base_filter.is_valid():
		return bool(base_filter.call(item_data))
	return bool(item_data.get("is_base", false))

# 判断当前是否满足使用材料条件。
func _can_use_as_material(item_data: Dictionary) -> bool:
	if base_item.is_empty():
		return false
	if material_filter.is_valid():
		return bool(material_filter.call(base_item, item_data))
	return bool(item_data.get("is_material", true))

# 判断当前是否满足合成条件。
func _can_craft() -> bool:
	if not selected_blueprint.is_empty():
		return _has_blueprint_requirements(selected_blueprint)
	return not base_item.is_empty() and base_has_pending_changes and material_items.size() <= _get_socket_count(base_item)

# 判断当前背包材料是否满足蓝图需求。
func _has_blueprint_requirements(recipe_data: Dictionary) -> bool:
	var requirements: Array = _get_blueprint_requirements(recipe_data)
	if requirements.is_empty():
		return false
	for requirement in requirements:
		var need_data: Dictionary = requirement as Dictionary
		var item_id: String = str(need_data.get("id", ""))
		var need_count: int = int(need_data.get("count", 0))
		if _get_inventory_count_by_id(item_id) < need_count:
			return false
	return true

# 消耗蓝图需求材料。
func _consume_blueprint_requirements(recipe_data: Dictionary) -> void:
	var requirements: Array = _get_blueprint_requirements(recipe_data)
	for requirement in requirements:
		var need_data: Dictionary = requirement as Dictionary
		var item_id: String = str(need_data.get("id", ""))
		var need_count: int = int(need_data.get("count", 0))
		_take_item_count_from_inventory(item_id, need_count)

# 获取蓝图需求材料列表。
func _get_blueprint_requirements(recipe_data: Dictionary) -> Array:
	var result: Array = []
	var requirements: Array = recipe_data.get("requirements", []) as Array
	for requirement in requirements:
		if requirement is Dictionary:
			result.append((requirement as Dictionary).duplicate(true))
	return result

# 获取蓝图成品物品数据。
func _get_blueprint_result(recipe_data: Dictionary) -> Dictionary:
	var result_value: Variant = recipe_data.get("result", {})
	if result_value is Dictionary:
		var item_data: Dictionary = (result_value as Dictionary).duplicate(true)
		_ensure_base_socket_state(item_data)
		return item_data
	return {}

# 生成合成结果所需的数据或控件。
func _make_craft_result() -> Dictionary:
	if craft_handler.is_valid():
		var handled_result: Variant = craft_handler.call(base_item, material_items)
		if handled_result is Dictionary:
			var handled_item: Dictionary = handled_result as Dictionary
			_ensure_base_socket_state(handled_item)
			handled_item["embedded_materials"] = _duplicate_item_array(material_items)
			return handled_item
	return _make_socket_result(base_item, material_items, true)

# 生成镶嵌槽结果所需的数据或控件。
func _make_socket_result(source_base: Dictionary, source_materials: Array, make_new_instance: bool) -> Dictionary:
	if make_new_instance:
		crafted_count += 1
	var result: Dictionary = source_base.duplicate(true)
	_ensure_base_socket_state(result)
	result["name"] = _format_socket_result_name(result, source_materials)
	result["description"] = "由当前基底和材料临时合成的调试结果。"
	result["props"] = _merge_props(result, source_materials)
	if make_new_instance or str(result.get("instance_id", "")).is_empty():
		result["instance_id"] = "%s_crafted_%d" % [str(result.get("id", "item")), crafted_count]
	result["count"] = 1
	result["embedded_materials"] = _duplicate_item_array(source_materials)
	return result

# 获取结果文本行数据。
func _get_result_lines() -> Array:
	if base_item.is_empty():
		return []
	var preview_materials: Array = _get_preview_material_items()
	if result_preview_provider.is_valid():
		var preview: Variant = result_preview_provider.call(base_item, preview_materials)
		if preview is Array:
			return preview
	var lines: Array = []
	lines.append("基底：%s" % str(base_item.get("name", "-")))
	lines.append("镶嵌槽：%d/%d" % [preview_materials.size(), _get_socket_count(base_item)])
	var props: Dictionary = _merge_props(base_item, preview_materials)
	for key in props.keys():
		var suffix: String = "（%s）" % _text("previewing") if _has_material_preview() else ""
		lines.append("%s：%s%s" % [str(key), str(props[key]), suffix])
	return lines

# 实现属性的界面或数据处理逻辑。
func _merge_props(source_base: Dictionary, source_materials: Array) -> Dictionary:
	var result: Dictionary = {}
	var base_props: Dictionary = _get_base_props(source_base)
	for key in base_props.keys():
		result[key] = base_props[key]
	for item in source_materials:
		if not (item is Dictionary):
			continue
		var material_item: Dictionary = item as Dictionary
		var props: Dictionary = material_item.get("props", {}) as Dictionary
		for key in props.keys():
			if result.has(key) and result[key] is int and props[key] is int:
				result[key] += props[key]
			else:
				result[key] = props[key]
	return result

# 实现基底镶嵌槽状态的界面或数据处理逻辑。
func _ensure_base_socket_state(item_data: Dictionary) -> void:
	if not item_data.has("base_props"):
		var props: Dictionary = item_data.get("props", {}) as Dictionary
		item_data["base_props"] = props.duplicate(true)
	if not item_data.has("socket_count"):
		item_data["socket_count"] = _get_default_socket_count(item_data)
	if not item_data.has("embedded_materials"):
		item_data["embedded_materials"] = []

# 获取镶嵌槽数量数据。
func _get_socket_count(item_data: Dictionary) -> int:
	if item_data.is_empty():
		return 0
	return int(clamp(int(item_data.get("socket_count", _get_default_socket_count(item_data))), 0, max_material_slots))

# 获取默认镶嵌槽数量数据。
func _get_default_socket_count(item_data: Dictionary) -> int:
	if not bool(item_data.get("is_base", false)):
		return 0
	match str(item_data.get("quality", "common")).to_lower():
		"rare":
			return 4
		"epic":
			return 5
		"legendary":
			return 6
	return 3

# 获取已镶嵌材料数据。
func _get_embedded_materials(item_data: Dictionary) -> Array:
	var materials: Array = []
	var raw_materials: Array = item_data.get("embedded_materials", []) as Array
	for item in raw_materials:
		if item is Dictionary:
			materials.append((item as Dictionary).duplicate(true))
	return materials

# 实现基底已镶嵌材料的界面或数据处理逻辑。
func _sync_base_embedded_materials() -> void:
	if base_item.is_empty():
		return
	base_item["embedded_materials"] = _duplicate_item_array(material_items)

# 实现基底forreturn的界面或数据处理逻辑。
func _prepare_base_for_return() -> void:
	if base_item.is_empty():
		return
	if base_has_pending_changes:
		var embedded_count: int = _get_embedded_materials(base_item).size()
		for i in range(embedded_count, material_items.size()):
			var pending_item: Dictionary = material_items[i] as Dictionary
			_return_item_to_inventory(pending_item)
			item_removed_from_table.emit(pending_item)
	base_item["count"] = 1

# 实现物品数组的界面或数据处理逻辑。
func _duplicate_item_array(items: Array) -> Array:
	var result: Array = []
	for item in items:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result

# 格式化镶嵌槽结果名称的显示文本。
func _format_socket_result_name(item_data: Dictionary, source_materials: Array) -> String:
	var upgrade_level: int = int(item_data.get("upgrade_level", 0))
	var base_name: String = str(item_data.get("base_name", item_data.get("name", "Result")))
	var suffix: String = ""
	if upgrade_level > 0:
		suffix = " Lv.%d" % upgrade_level
	if source_materials.size() > 0:
		return "%s%s +%d" % [base_name, suffix, source_materials.size()]
	return "%s%s" % [base_name, suffix]

# 判断当前是否满足升级基底条件。
func _can_upgrade_base() -> bool:
	return not _get_upgrade_candidate_indexes().is_empty()

# 获取升级候选物品索引数据。
func _get_upgrade_candidate_indexes() -> Array[int]:
	var result: Array[int] = []
	if base_item.is_empty():
		return result
	var base_id: String = str(base_item.get("id", ""))
	var base_quality: String = str(base_item.get("quality", "")).to_lower()
	for i in range(inventory_items.size()):
		var item: Dictionary = inventory_items[i] as Dictionary
		if _get_item_count(item) <= 0:
			continue
		if str(item.get("id", "")) != base_id:
			continue
		if str(item.get("quality", "")).to_lower() != base_quality:
			continue
		if not bool(item.get("is_base", false)):
			continue
		result.append(i)
	return result

# 实现升级基底的界面或数据处理逻辑。
func _consume_upgrade_base(upgrade_index: int) -> void:
	if upgrade_index < 0:
		return
	var upgrade_item: Dictionary = inventory_items[upgrade_index] as Dictionary
	for embedded_item in _get_embedded_materials(upgrade_item):
		if embedded_item is Dictionary:
			_return_item_to_inventory(embedded_item as Dictionary)
	upgrade_item["count"] = max(0, _get_item_count(upgrade_item) - 1)

# 生成升级结果所需的数据或控件。
func _make_upgrade_result(source_base: Dictionary) -> Dictionary:
	var result: Dictionary = source_base.duplicate(true)
	_ensure_base_socket_state(result)
	var upgrade_level: int = int(result.get("upgrade_level", 0)) + 1
	result["upgrade_level"] = upgrade_level
	result["base_name"] = str(result.get("base_name", result.get("name", "-")))
	result["socket_count"] = min(max_material_slots, _get_socket_count(result) + 1)
	var base_props: Dictionary = _get_base_props(result)
	var upgraded_props: Dictionary = {}
	for key in base_props.keys():
		if base_props[key] is int:
			upgraded_props[key] = int(base_props[key]) + 1
		elif base_props[key] is float:
			upgraded_props[key] = float(base_props[key]) + 1.0
		else:
			upgraded_props[key] = base_props[key]
	result["base_props"] = upgraded_props
	result["embedded_materials"] = _duplicate_item_array(material_items)
	result["props"] = _merge_props(result, material_items)
	result["name"] = _format_socket_result_name(result, material_items)
	result["count"] = 1
	return result

# 获取基底属性数据。
func _get_base_props(item_data: Dictionary) -> Dictionary:
	var props: Dictionary = item_data.get("base_props", item_data.get("props", {})) as Dictionary
	return props

# 获取已镶嵌材料数量数据。
func _get_embedded_material_count() -> int:
	return _get_embedded_materials(base_item).size()

# 实现物品from背包的界面或数据处理逻辑。
func _take_item_from_inventory(item_data: Dictionary) -> void:
	var item_key: String = _get_item_key(item_data)
	for item in inventory_items:
		if _get_item_key(item) == item_key:
			item["count"] = max(0, _get_item_count(item) - 1)
			return

# 获取背包中指定物品编号的总数量。
func _get_inventory_count_by_id(item_id: String) -> int:
	var total_count: int = 0
	for item in inventory_items:
		var item_data: Dictionary = item as Dictionary
		if str(item_data.get("id", "")) == item_id:
			total_count += _get_item_count(item_data)
	return total_count

# 按物品编号从背包中扣除指定数量。
func _take_item_count_from_inventory(item_id: String, count: int) -> void:
	var left_count: int = count
	for item in inventory_items:
		if left_count <= 0:
			return
		var item_data: Dictionary = item as Dictionary
		if str(item_data.get("id", "")) != item_id:
			continue
		var item_count: int = _get_item_count(item_data)
		var take_count: int = min(item_count, left_count)
		item_data["count"] = max(0, item_count - take_count)
		left_count -= take_count

# 实现物品to背包的界面或数据处理逻辑。
func _return_item_to_inventory(item_data: Dictionary) -> void:
	_apply_test_map_hunger_rules(item_data)
	var returned_item: Dictionary = item_data.duplicate(true)
	returned_item["count"] = 1
	returned_item["is_unread"] = false
	inventory_items.append(returned_item)

# 将探索或开包新增物品加入背包前排，并与未读同类物品合并。
func _add_new_item_to_inventory(item_data: Dictionary) -> void:
	_apply_test_map_hunger_rules(item_data)
	var new_item: Dictionary = item_data.duplicate(true)
	new_item["count"] = max(1, _get_item_count(new_item))
	new_item["is_unread"] = true
	var merge_key: String = _get_inventory_merge_key(new_item)
	for item in inventory_items:
		var old_item: Dictionary = item as Dictionary
		if not bool(old_item.get("is_unread", false)):
			continue
		if not _can_merge_inventory_item(old_item):
			continue
		if _get_inventory_merge_key(old_item) != merge_key:
			continue
		old_item["count"] = _get_item_count(old_item) + _get_item_count(new_item)
		return
	inventory_items.insert(0, new_item)

# 合并背包中可堆叠的同类物品。
func _merge_inventory_items() -> void:
	var merged_items: Array = []
	var merged_index_by_key: Dictionary = {}
	for item in inventory_items:
		var item_data: Dictionary = item as Dictionary
		if _get_item_count(item_data) <= 0:
			continue
		if not _can_merge_inventory_item(item_data):
			merged_items.append(item_data)
			continue
		var merge_key: String = _get_inventory_merge_key(item_data)
		if merged_index_by_key.has(merge_key):
			var target_index: int = int(merged_index_by_key[merge_key])
			var target_item: Dictionary = merged_items[target_index] as Dictionary
			target_item["count"] = _get_item_count(target_item) + _get_item_count(item_data)
			target_item["is_unread"] = bool(target_item.get("is_unread", false)) or bool(item_data.get("is_unread", false))
		else:
			var merged_item: Dictionary = item_data.duplicate(true)
			merged_index_by_key[merge_key] = merged_items.size()
			merged_items.append(merged_item)
	inventory_items = merged_items

# 判断背包物品是否允许在整理时合并。
func _can_merge_inventory_item(item_data: Dictionary) -> bool:
	if not str(item_data.get("instance_id", "")).is_empty():
		return false
	return str(item_data.get("category", "")) in [CATEGORY_MATERIAL, CATEGORY_FOOD, CATEGORY_MAP]

# 获取背包整理合并时使用的物品键。
func _get_inventory_merge_key(item_data: Dictionary) -> String:
	return "%s|%s|%s" % [
		str(item_data.get("id", "")),
		str(item_data.get("quality", "")),
		str(item_data.get("category", ""))
	]

# 按官方背包规则排序物品。
func _sort_inventory_items(a: Dictionary, b: Dictionary) -> bool:
	var category_a: int = int(INVENTORY_CATEGORY_SORT.get(str(a.get("category", "")), 999))
	var category_b: int = int(INVENTORY_CATEGORY_SORT.get(str(b.get("category", "")), 999))
	if category_a != category_b:
		return category_a < category_b
	var quality_a: int = int(INVENTORY_QUALITY_SORT.get(str(a.get("quality", "common")), 999))
	var quality_b: int = int(INVENTORY_QUALITY_SORT.get(str(b.get("quality", "common")), 999))
	if quality_a != quality_b:
		return quality_a < quality_b
	var name_a: String = str(a.get("name", ""))
	var name_b: String = str(b.get("name", ""))
	if name_a != name_b:
		return name_a < name_b
	return str(a.get("id", "")) < str(b.get("id", ""))

# 生成槽位按钮所需的数据或控件。
func _make_slot_button(label_text: String, show_hover: bool) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.add_theme_font_size_override("font_size", 12)
	button.custom_minimum_size = slot_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	_apply_button_style(button, Color(0.20, 0.23, 0.28), Color(0.43, 0.50, 0.58), Color(0.30, 0.35, 0.43), Color(0.13, 0.15, 0.18))
	if not show_hover:
		button.mouse_filter = Control.MOUSE_FILTER_PASS
	return button

# 实现tooltip的界面或数据处理逻辑。
func _bind_tooltip(slot: Control, item_data: Dictionary) -> void:
	slot.mouse_entered.connect(_show_tooltip_for_slot.bind(slot, item_data))
	slot.mouse_exited.connect(_hide_tooltip)

# 实现tooltip的界面或数据处理逻辑。
func _clear_tooltip(slot: Control) -> void:
	for connection in slot.mouse_entered.get_connections():
		slot.mouse_entered.disconnect(connection.callable)
	for connection in slot.mouse_exited.get_connections():
		slot.mouse_exited.disconnect(connection.callable)

# 显示tooltipfor槽位，并设置相关临时状态。
func _show_tooltip_for_slot(slot: Control, item_data: Dictionary) -> void:
	_set_tooltip_line_limits(3, 4)
	tooltip_name.text = str(item_data.get("name", "-"))
	tooltip_type.text = _get_type_text(str(item_data.get("category", CATEGORY_MATERIAL)))
	tooltip_desc.text = _limit_text(str(item_data.get("description", "")), TOOLTIP_DESC_MAX_LENGTH)
	tooltip_props.text = _limit_text(_format_props(item_data.get("props", {})), TOOLTIP_PROPS_MAX_LENGTH)
	_apply_tooltip_content_size(tooltip_max_size)
	tooltip_panel.visible = true
	await get_tree().process_frame
	if not is_instance_valid(slot):
		return
	if open_pack_overlay.visible:
		_place_item_tooltip_top_aligned(slot, Rect2(Vector2.ZERO, get_viewport_rect().size), tooltip_max_size)
	else:
		_place_tooltip(slot)

# 隐藏tooltip，并清理相关临时状态。
func _hide_tooltip() -> void:
	tooltip_panel.visible = false

# 设置tooltip文本行limits数据，并同步刷新界面。
func _set_tooltip_line_limits(desc_lines: int, props_lines: int) -> void:
	tooltip_desc.max_lines_visible = desc_lines
	tooltip_props.max_lines_visible = props_lines

# 计算并摆放tooltip的界面位置。
func _place_tooltip(slot: Control) -> void:
	var inventory_rect: Rect2 = Rect2(inventory_panel.global_position, inventory_panel.size)
	var screen_rect: Rect2 = Rect2(Vector2.ZERO, get_viewport_rect().size)
	var slot_center: Vector2 = slot.global_position + slot.size * 0.5
	if inventory_rect.has_point(slot_center):
		var bound_rect: Rect2 = inventory_rect.intersection(screen_rect)
		if bound_rect.size.x <= 0.0 or bound_rect.size.y <= 0.0:
			bound_rect = screen_rect
		_place_inventory_tooltip(slot, bound_rect, tooltip_max_size)
	else:
		_place_item_tooltip_left_aligned(slot, screen_rect, tooltip_max_size)

# 计算并摆放背包tooltip的界面位置。
func _place_inventory_tooltip(slot: Control, bound_rect: Rect2, max_size_value: Vector2) -> void:
	var slot_rect: Rect2 = Rect2(slot.global_position, slot.size)
	var tip_size: Vector2 = _clamp_tooltip_size(max_size_value, bound_rect)
	tip_size.x = max(TOOLTIP_MIN_SIZE.x, bound_rect.size.x - 16.0)
	tip_size.y = min(tip_size.y, bound_rect.size.y - 16.0)
	var x: float = bound_rect.position.x + 8.0
	var y: float = slot_rect.end.y
	if y + tip_size.y > bound_rect.end.y - 8.0:
		y = slot_rect.position.y - tip_size.y
	y = clamp(y, bound_rect.position.y + 8.0, bound_rect.end.y - tip_size.y - 8.0)
	tooltip_panel.custom_minimum_size = tip_size
	tooltip_panel.size = tip_size
	tooltip_panel.global_position = Vector2(x, y)

# 计算并摆放tooltipin矩形范围的界面位置。
func _place_tooltip_in_rect(slot: Control, bound_rect: Rect2, max_size_value: Vector2, keep_side: bool = false) -> void:
	var slot_rect: Rect2 = Rect2(slot.global_position, slot.size)
	var max_size: Vector2 = Vector2(
		min(max_size_value.x, bound_rect.size.x - 16.0),
		min(max_size_value.y, bound_rect.size.y - 16.0)
	)
	var tip_size: Vector2 = Vector2(
		min(tooltip_panel.size.x, max_size.x),
		min(tooltip_panel.size.y, max_size.y)
	)
	tooltip_panel.size = tip_size
	var show_right: bool = slot_rect.get_center().x < bound_rect.get_center().x
	var show_down: bool = slot_rect.get_center().y < bound_rect.get_center().y
	var x: float = slot_rect.end.x + 12.0 if show_right else slot_rect.position.x - tip_size.x - 12.0
	var y: float = slot_rect.position.y if show_down else slot_rect.end.y - tip_size.y
	x = clamp(x, bound_rect.position.x + 8.0, bound_rect.end.x - tip_size.x - 8.0)
	if keep_side:
		if y + tip_size.y > bound_rect.end.y - 8.0:
			y = bound_rect.end.y - tip_size.y - 8.0
		if y < bound_rect.position.y + 8.0:
			y = bound_rect.position.y + 8.0
	else:
		y = clamp(y, bound_rect.position.y + 8.0, bound_rect.end.y - tip_size.y - 8.0)
	tooltip_panel.custom_minimum_size = tip_size
	tooltip_panel.global_position = Vector2(x, y)

# 计算并摆放tooltip默认向下向右的界面位置。
func _place_tooltip_default_down_right(slot: Control, bound_rect: Rect2, max_size_value: Vector2) -> void:
	var slot_rect: Rect2 = Rect2(slot.global_position, slot.size)
	var tip_size: Vector2 = _clamp_tooltip_size(max_size_value, bound_rect)
	var x: float = slot_rect.end.x + 12.0
	var y: float = slot_rect.end.y + 12.0
	if x + tip_size.x > bound_rect.end.x - 8.0:
		x = slot_rect.position.x - tip_size.x - 12.0
	if y + tip_size.y > bound_rect.end.y - 8.0:
		y = slot_rect.position.y - tip_size.y - 12.0
	x = clamp(x, bound_rect.position.x + 8.0, bound_rect.end.x - tip_size.x - 8.0)
	y = clamp(y, bound_rect.position.y + 8.0, bound_rect.end.y - tip_size.y - 8.0)
	tooltip_panel.custom_minimum_size = tip_size
	tooltip_panel.size = tip_size
	tooltip_panel.global_position = Vector2(x, y)

# 计算并摆放卡包tooltip的界面位置。
func _place_pack_tooltip(slot: Control, bound_rect: Rect2, max_size_value: Vector2) -> void:
	var slot_rect: Rect2 = Rect2(slot.global_position, slot.size)
	var tip_size: Vector2 = _clamp_tooltip_size(max_size_value, bound_rect)
	var x: float = slot_rect.end.x + 12.0
	if x + tip_size.x > bound_rect.end.x - 8.0:
		x = slot_rect.position.x - tip_size.x - 12.0
	var y: float = slot_rect.position.y
	if y + tip_size.y > bound_rect.end.y - 8.0:
		y = bound_rect.end.y - tip_size.y - 8.0
	x = clamp(x, bound_rect.position.x + 8.0, bound_rect.end.x - tip_size.x - 8.0)
	y = max(y, bound_rect.position.y + 8.0)
	tooltip_panel.custom_minimum_size = tip_size
	tooltip_panel.size = tip_size
	tooltip_panel.global_position = Vector2(x, y)

# 计算并摆放物品tooltip上沿对齐的界面位置。
func _place_item_tooltip_top_aligned(slot: Control, bound_rect: Rect2, max_size_value: Vector2) -> void:
	var slot_rect: Rect2 = Rect2(slot.global_position, slot.size)
	var tip_size: Vector2 = _clamp_tooltip_size(max_size_value, bound_rect)
	var x: float = slot_rect.end.x + 12.0
	if x + tip_size.x > bound_rect.end.x - 8.0:
		x = slot_rect.position.x - tip_size.x - 12.0
	var y: float = slot_rect.position.y
	if y + tip_size.y > bound_rect.end.y - 8.0:
		y = bound_rect.end.y - tip_size.y - 8.0
	x = clamp(x, bound_rect.position.x + 8.0, bound_rect.end.x - tip_size.x - 8.0)
	y = max(y, bound_rect.position.y + 8.0)
	tooltip_panel.custom_minimum_size = tip_size
	tooltip_panel.size = tip_size
	tooltip_panel.global_position = Vector2(x, y)

# 计算并摆放物品tooltip左侧对齐的界面位置。
func _place_item_tooltip_left_aligned(slot: Control, bound_rect: Rect2, max_size_value: Vector2) -> void:
	var slot_rect: Rect2 = Rect2(slot.global_position, slot.size)
	var tip_size: Vector2 = _clamp_tooltip_size(max_size_value, bound_rect)
	var x: float = slot_rect.position.x - tip_size.x - 12.0
	if x < bound_rect.position.x + 8.0:
		x = slot_rect.end.x + 12.0
	var y: float = slot_rect.position.y
	if y + tip_size.y > bound_rect.end.y - 8.0:
		y = slot_rect.end.y - tip_size.y
	x = clamp(x, bound_rect.position.x + 8.0, bound_rect.end.x - tip_size.x - 8.0)
	y = max(y, bound_rect.position.y + 8.0)
	tooltip_panel.custom_minimum_size = tip_size
	tooltip_panel.size = tip_size
	tooltip_panel.global_position = Vector2(x, y)

# 实现clamptooltip尺寸的界面或数据处理逻辑。
func _clamp_tooltip_size(max_size_value: Vector2, bound_rect: Rect2) -> Vector2:
	var max_size: Vector2 = Vector2(
		min(max_size_value.x, bound_rect.size.x - 16.0),
		min(max_size_value.y, bound_rect.size.y - 16.0)
	)
	var desired_size: Vector2 = tooltip_panel.custom_minimum_size
	return Vector2(
		min(desired_size.x, max_size.x),
		min(desired_size.y, max_size.y)
	)

# 应用tooltip内容尺寸样式或状态。
func _apply_tooltip_content_size(max_size_value: Vector2) -> void:
	var desired_size: Vector2 = _measure_tooltip_content_size(max_size_value)
	tooltip_panel.custom_minimum_size = desired_size
	tooltip_panel.size = desired_size

# 实现measuretooltip内容尺寸的界面或数据处理逻辑。
func _measure_tooltip_content_size(max_size_value: Vector2) -> Vector2:
	var longest_line: int = 0
	var line_count: int = 0
	for text_value in [tooltip_name.text, tooltip_type.text, tooltip_desc.text, tooltip_props.text]:
		var lines: PackedStringArray = str(text_value).split("\n")
		line_count += max(1, lines.size())
		for line in lines:
			longest_line = max(longest_line, str(line).length())
	var width: float = clamp(float(longest_line) * 12.0 + TOOLTIP_PADDING_SIZE.x, TOOLTIP_MIN_SIZE.x, max_size_value.x)
	var height: float = clamp(float(line_count) * 22.0 + TOOLTIP_PADDING_SIZE.y, TOOLTIP_MIN_SIZE.y, max_size_value.y)
	return Vector2(width, height)

# 向界面或数据中添加结果文本行。
func _add_result_line(text_value: String, is_title: bool) -> void:
	var label: Label = Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_title:
		label.add_theme_font_size_override("font_size", 22)
	base_result_list.add_child(label)

# 格式化物品槽位文本的显示文本。
func _format_item_slot_text(item_data: Dictionary) -> String:
	var count: int = _get_item_count(item_data)
	if count > 1:
		return "%s\nx%d" % [str(item_data.get("name", "-")), count]
	return str(item_data.get("name", "-"))

# 格式化属性的显示文本。
func _format_props(props: Variant) -> String:
	if not (props is Dictionary):
		return ""
	var lines: Array[String] = []
	for key in props.keys():
		lines.append("%s：%s" % [str(key), str(props[key])])
	return "\n".join(lines)

# 实现文本的界面或数据处理逻辑。
func _limit_text(text_value: String, max_length: int) -> String:
	if text_value.length() <= max_length:
		return text_value
	return text_value.substr(0, max_length) + "..."

# 获取物品数量数据。
func _get_item_count(item_data: Dictionary) -> int:
	return int(item_data.get("count", 1))

# 获取物品key数据。
func _get_item_key(item_data: Dictionary) -> String:
	var instance_id: String = str(item_data.get("instance_id", ""))
	if not instance_id.is_empty():
		return instance_id
	return str(item_data.get("id", ""))

# 实现is物品in分类的界面或数据处理逻辑。
func _is_item_in_category(item_data: Dictionary, category: String) -> bool:
	if category == CATEGORY_ALL:
		return true
	return str(item_data.get("category", "")) == category

# 获取type文本数据。
func _get_type_text(category: String) -> String:
	match category:
		CATEGORY_EQUIPMENT:
			return _text("equipment")
		CATEGORY_MAP:
			return _text("map")
		CATEGORY_MATERIAL:
			return _text("material")
		CATEGORY_FOOD:
			return _text("food")
	return _text("all")

# 获取品质color数据。
func _get_quality_color(item_data: Dictionary) -> Color:
	match str(item_data.get("quality", "common")):
		"rare":
			return Color.CORNFLOWER_BLUE
		"epic":
			return Color.PURPLE
		"legendary":
			return Color.ORANGE
	return Color.WHITE

# 保留旧状态提示接口，当前界面已不显示状态栏。
func _set_status(_text_value: String) -> void:
	pass

# 实现台面变化的界面或数据处理逻辑。
func _emit_table_changed() -> void:
	workbench_changed.emit(base_item, material_items)

# 从临时文本表中读取界面文案。
func _text(key: String) -> String:
	return str(TEXT.get(key, key))

# 读取地图element配置物品配置数据。
func _load_map_element_config_items() -> Array:
	var items: Array = []
	if not FileAccess.file_exists(MAP_ELEMENTS_CSV_PATH):
		return items
	var file: FileAccess = FileAccess.open(MAP_ELEMENTS_CSV_PATH, FileAccess.READ)
	if not file:
		return items
	var header: PackedStringArray = file.get_csv_line()
	var col: Dictionary = _map_csv_header(header)
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() < header.size():
			continue
		var item_id: String = _csv_value(line, col, "id")
		if _should_skip_config_row(item_id):
			continue
		var raw_category: String = _csv_value(line, col, "category")
		var category: String = CATEGORY_MAP if raw_category == MAP_BASE_CATEGORY else CATEGORY_MATERIAL
		var is_map_element: bool = raw_category != MAP_BASE_CATEGORY
		var pack_probability: float = _csv_value(line, col, "pack_probability").to_float()
		var props: Dictionary = _parse_props(_csv_value(line, col, "props"))
		var socket_count: int = _csv_value(line, col, "socket_count").to_int()
		var hunger_cost: int = _get_config_hunger_cost(raw_category, _csv_value(line, col, "quality"))
		if socket_count <= 0 and _parse_bool(_csv_value(line, col, "is_base")):
			socket_count = _get_default_socket_count({
				"is_base": true,
				"quality": _csv_value(line, col, "quality").to_lower()
			})
		items.append({
			"id": item_id,
			"name": _csv_value(line, col, "name"),
			"base_name": _csv_value(line, col, "name"),
			"category": category,
			"map_category": raw_category,
			"quality": _csv_value(line, col, "quality").to_lower(),
			"description": _csv_value(line, col, "description"),
			"count": max(1, _csv_value(line, col, "count").to_int()),
			"is_base": _parse_bool(_csv_value(line, col, "is_base")),
			"is_material": _parse_bool(_csv_value(line, col, "is_material")),
			"is_map_element": is_map_element,
			"is_shop_item": pack_probability > 0.0,
			"socket_count": socket_count,
			"hunger_cost": hunger_cost,
			"hunger_debuff": DEFAULT_MAP_HUNGER_DEBUFF,
			"base_props": props.duplicate(true),
			"embedded_materials": [],
			"pack_probability": pack_probability,
			"props": props
		})
	return items

# 实现地图CSV表头的界面或数据处理逻辑。
func _map_csv_header(header: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for i in range(header.size()):
		result[str(header[i]).strip_edges()] = i
	return result

# 实现CSV值的界面或数据处理逻辑。
func _csv_value(line: PackedStringArray, col: Dictionary, key: String) -> String:
	if not col.has(key):
		return ""
	var index: int = int(col[key])
	if index < 0 or index >= line.size():
		return ""
	return str(line[index]).strip_edges()

# 按地图配置和品质生成默认饱食度需求。
func _get_config_hunger_cost(raw_category: String, quality: String) -> int:
	if raw_category != MAP_BASE_CATEGORY:
		return 0
	match quality.to_lower():
		"rare":
			return 40
		"epic":
			return 55
		"legendary":
			return 70
	return DEFAULT_MAP_HUNGER_COST

# 实现shouldskip配置行的界面或数据处理逻辑。
func _should_skip_config_row(item_id: String) -> bool:
	return item_id.is_empty() or item_id.begins_with("__") or item_id.begins_with("#")

# 解析布尔值配置文本。
func _parse_bool(value: String) -> bool:
	var text: String = value.strip_edges().to_upper()
	return text == "TRUE" or text == "1" or text == "YES" or text == "是"

# 解析属性配置文本。
func _parse_props(value: String) -> Dictionary:
	var props: Dictionary = {}
	if value.is_empty():
		return props
	for part in value.split(";"):
		var piece: String = str(part).strip_edges()
		if piece.is_empty() or not piece.contains(":"):
			continue
		var pair: PackedStringArray = piece.split(":", false, 1)
		var key: String = str(pair[0]).strip_edges()
		var raw_value: String = str(pair[1]).strip_edges()
		if raw_value.is_valid_int():
			props[key] = raw_value.to_int()
		elif raw_value.is_valid_float():
			props[key] = raw_value.to_float()
		else:
			props[key] = raw_value
	return props

#endregion
