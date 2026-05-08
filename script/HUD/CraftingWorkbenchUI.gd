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
@export var max_material_slots: int = 12 ## 台面材料槽位数量
@export var slot_size: Vector2 = Vector2(88, 88) ## 背包与台面槽位尺寸
@export var tooltip_max_size: Vector2 = Vector2(360, 260) ## 悬浮说明最大尺寸

var base_filter: Callable ## 外部基底筛选接口
var material_filter: Callable ## 外部材料筛选接口
var result_preview_provider: Callable ## 外部结果预览接口
var craft_handler: Callable ## 外部合成执行接口
#endregion

#region 2. 内部状态数据
const TEXT := {
	"title": "通用合成台",
	"base_empty": "选择基底",
	"material_empty": "材料槽",
	"result_title": "成品属性",
	"result_empty": "请先选择基底和材料",
	"craft": "合成",
	"all": "全部",
	"equipment": "装备",
	"map": "地图",
	"material": "材料",
	"status_select_base": "请先从背包选择一个可作为基底的物品。",
	"status_select_material": "已选择基底，继续选择材料。",
	"status_ready": "条件满足，可以合成。",
	"status_crafted": "合成完成，成品保留在基底槽。",
	"status_need_material": "至少需要 1 个材料才能合成。",
	"status_no_slot": "材料槽已满。",
	"status_invalid_base": "该物品不能作为基底。",
	"status_invalid_material": "该物品不能作为当前基底的材料。",
	"shop": "购买地图元素",
	"back_to_craft": "前往合成表",
	"shop_title": "地图元素卡包",
	"gold": "金币：%d",
	"pack_stock": "剩余：%d",
	"pack_price": "价格：%d",
	"pack_sold_out": "已售空",
	"pack_detail_unknown": "%s + %s",
	"open_pack_title": "获得地图元素",
	"open_pack_close": "点击任意位置关闭界面"
}

const CATEGORY_ALL := "all"
const CATEGORY_EQUIPMENT := "equipment"
const CATEGORY_MAP := "map"
const CATEGORY_MATERIAL := "material"
const MODE_CRAFT := "craft"
const MODE_SHOP := "shop"
const MAP_BASE_CATEGORY := "map_base"
const MAP_PACK_ORDER := ["terrain", "water", "site", "plant", "mineral", "food", "creature", "hazard"]
const MAP_CATEGORY_NAMES := {
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
const PACK_TOOLTIP_MAX_SIZE := Vector2(460, 900)
const TOOLTIP_MIN_SIZE := Vector2(180, 96)
const TOOLTIP_PADDING_SIZE := Vector2(36, 42)
const TOOLTIP_DESC_MAX_LENGTH := 52
const TOOLTIP_PROPS_MAX_LENGTH := 80
const MAP_ELEMENTS_CSV_PATH := "res://script/Data/CSVs/MapElements.txt"

@onready var mode_switch_button: Button = $Root/MainPanel/MainLayout/HeaderBar/ModeSwitchButton
@onready var title_label: Label = $Root/MainPanel/MainLayout/HeaderBar/TitleLabel
@onready var gold_label: Label = $Root/MainPanel/MainLayout/HeaderBar/GoldLabel
@onready var workbench_panel: PanelContainer = $Root/MainPanel/MainLayout/WorkbenchPanel
@onready var base_slot: Button = $Root/MainPanel/MainLayout/WorkbenchPanel/WorkbenchLayout/BasePanel/BaseSlot
@onready var material_grid: GridContainer = $Root/MainPanel/MainLayout/WorkbenchPanel/WorkbenchLayout/MaterialPanel/MaterialGrid
@onready var result_list: VBoxContainer = $Root/MainPanel/MainLayout/WorkbenchPanel/WorkbenchLayout/ResultPanel/ResultScroll/ResultList
@onready var store_panel: PanelContainer = $Root/MainPanel/MainLayout/StorePanel
@onready var pack_scroll: ScrollContainer = $Root/MainPanel/MainLayout/StorePanel/StoreLayout/PackScroll
@onready var pack_row: HBoxContainer = $Root/MainPanel/MainLayout/StorePanel/StoreLayout/PackScroll/PackRow
@onready var craft_button_margin: MarginContainer = $Root/MainPanel/MainLayout/CraftButtonMargin
@onready var craft_button: Button = $Root/MainPanel/MainLayout/CraftButtonMargin/CraftButtonRow/CraftButton
@onready var status_label: Label = $Root/MainPanel/MainLayout/CraftButtonMargin/CraftButtonRow/StatusLabel
@onready var inventory_panel: PanelContainer = $Root/MainPanel/MainLayout/InventoryPanel
@onready var tab_container: HBoxContainer = $Root/MainPanel/MainLayout/InventoryPanel/InventoryLayout/TabContainer
@onready var inventory_grid: GridContainer = $Root/MainPanel/MainLayout/InventoryPanel/InventoryLayout/InventoryScroll/InventoryGrid
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

var inventory_items: Array = []
var material_items: Array = []
var material_slot_buttons: Array[Button] = []
var tab_buttons: Dictionary = {}
var base_item: Dictionary = {}
var current_category: String = CATEGORY_ALL
var current_mode: String = MODE_CRAFT
var crafted_count: int = 0
var gold: int = DEFAULT_START_GOLD
var map_element_items: Array = []
var map_element_by_id: Dictionary = {}
var map_pack_products: Array = []
var discovered_map_element_ids: Dictionary = {}
var pending_open_pack_items: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
#endregion

#region 3. 生命周期与核心逻辑
func _ready() -> void:
	rng.randomize()
	tooltip_panel.visible = false
	tooltip_panel.z_index = 100
	open_pack_overlay.z_index = 20
	fly_text_layer.z_index = 30
	open_pack_overlay.visible = false
	title_label.text = _text("title")
	craft_button.text = _text("craft")
	mode_switch_button.text = _text("shop")
	open_pack_title.text = _text("open_pack_title")
	open_pack_close_label.text = _text("open_pack_close")
	mode_switch_button.pressed.connect(_toggle_shop_mode)
	base_slot.pressed.connect(_on_base_slot_pressed)
	craft_button.pressed.connect(_on_craft_pressed)
	pack_scroll.gui_input.connect(_on_pack_scroll_gui_input)
	open_pack_overlay.gui_input.connect(_on_open_pack_overlay_gui_input)
	_build_material_slots()
	_build_tabs()
	_update_gold_label()
	_apply_mode()
	if use_config_items:
		_set_shop_source_items(_load_map_element_config_items())
	set_inventory_items([])

# 设置外部物品数据，后续真实背包接入时调用
func set_inventory_items(items: Array) -> void:
	inventory_items.clear()
	for item in items:
		if item is Dictionary:
			inventory_items.append(item.duplicate(true))
	_refresh_all()

# 设置商店卡包来源。它只用于生成商品，不会自动放入背包。
func _set_shop_source_items(items: Array) -> void:
	map_element_items.clear()
	map_element_by_id.clear()
	for item in items:
		if item is Dictionary and bool(item.get("is_map_element", false)):
			var map_item: Dictionary = (item as Dictionary).duplicate(true)
			map_item["count"] = 1
			map_element_items.append(map_item)
			map_element_by_id[str(map_item.get("id", ""))] = map_item
	_rebuild_pack_products()

# 设置外部筛选与合成接口
func set_rule_interfaces(new_base_filter: Callable, new_material_filter: Callable, new_preview_provider: Callable, new_craft_handler: Callable) -> void:
	base_filter = new_base_filter
	material_filter = new_material_filter
	result_preview_provider = new_preview_provider
	craft_handler = new_craft_handler
	_refresh_all()

# 清空台面，把已放入台面的物品退回背包
func clear_workbench() -> void:
	if not base_item.is_empty():
		_return_item_to_inventory(base_item)
		base_item.clear()
	for item in material_items:
		_return_item_to_inventory(item)
	material_items.clear()
	_refresh_all()

func set_gold(value: int) -> void:
	gold = value
	_update_gold_label()

func _on_inventory_slot_pressed(item_data: Dictionary) -> void:
	if base_item.is_empty():
		if _can_use_as_base(item_data):
			_move_item_to_base(item_data)
		else:
			_set_status(_text("status_invalid_base"))
		return
	if _can_use_as_material(item_data):
		_add_material(item_data)
	else:
		_set_status(_text("status_invalid_material"))

func _on_base_slot_pressed() -> void:
	if base_item.is_empty():
		return
	_return_item_to_inventory(base_item)
	item_removed_from_table.emit(base_item)
	base_item.clear()
	for item in material_items:
		_return_item_to_inventory(item)
		item_removed_from_table.emit(item)
	material_items.clear()
	_refresh_all()

func _on_material_slot_pressed(index: int) -> void:
	if index < 0 or index >= material_items.size():
		return
	var item_data: Dictionary = material_items[index]
	material_items.remove_at(index)
	_return_item_to_inventory(item_data)
	item_removed_from_table.emit(item_data)
	_refresh_all()

func _on_craft_pressed() -> void:
	if not _can_craft():
		return
	craft_requested.emit(base_item, material_items)
	var result: Dictionary = _make_craft_result()
	base_item = result
	material_items.clear()
	_set_status(_text("status_crafted"))
	_refresh_all()

func _toggle_shop_mode() -> void:
	current_mode = MODE_SHOP if current_mode == MODE_CRAFT else MODE_CRAFT
	_hide_tooltip()
	_apply_mode()

func _apply_mode() -> void:
	var is_shop: bool = current_mode == MODE_SHOP
	workbench_panel.visible = not is_shop
	store_panel.visible = is_shop
	craft_button_margin.visible = not is_shop
	title_label.text = _text("shop_title") if is_shop else _text("title")
	mode_switch_button.text = _text("back_to_craft") if is_shop else _text("shop")
	if is_shop:
		_refresh_pack_products()

func _on_pack_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and (mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var bar: HScrollBar = pack_scroll.get_h_scroll_bar()
			var direction: int = -1 if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			bar.value = clamp(bar.value + direction * 80.0, bar.min_value, bar.max_value)
			pack_scroll.accept_event()

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

func _on_open_pack_overlay_gui_input(event: InputEvent) -> void:
	if not open_pack_overlay.visible:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		_close_open_pack_overlay()
		open_pack_overlay.accept_event()
#endregion

#region 4. 辅助方法
func _build_material_slots() -> void:
	for child in material_grid.get_children():
		child.queue_free()
	material_slot_buttons.clear()
	for i in range(max_material_slots):
		var slot: Button = _make_slot_button(_text("material_empty"), false)
		slot.pressed.connect(_on_material_slot_pressed.bind(i))
		material_grid.add_child(slot)
		material_slot_buttons.append(slot)

func _build_tabs() -> void:
	for child in tab_container.get_children():
		child.queue_free()
	tab_buttons.clear()
	var tabs: Array = [
		{"id": CATEGORY_ALL, "name": _text("all")},
		{"id": CATEGORY_EQUIPMENT, "name": _text("equipment")},
		{"id": CATEGORY_MAP, "name": _text("map")},
		{"id": CATEGORY_MATERIAL, "name": _text("material")}
	]
	for tab in tabs:
		var button: Button = Button.new()
		button.text = tab["name"]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(78, 18)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_on_tab_pressed.bind(tab["id"]))
		tab_container.add_child(button)
		tab_buttons[tab["id"]] = button

func _on_tab_pressed(tab_id: String) -> void:
	current_category = tab_id
	_refresh_inventory()
	_refresh_tabs()

func _refresh_all() -> void:
	_refresh_base_slot()
	_refresh_material_slots()
	_refresh_result_list()
	_refresh_pack_products()
	_refresh_inventory()
	_refresh_tabs()
	_update_craft_button()
	_update_gold_label()
	_emit_table_changed()

func _refresh_base_slot() -> void:
	if base_item.is_empty():
		base_slot.text = _text("base_empty")
		base_slot.modulate = Color(0.75, 0.75, 0.75)
	else:
		base_slot.text = _format_item_slot_text(base_item)
		base_slot.modulate = _get_quality_color(base_item)

func _refresh_material_slots() -> void:
	for i in range(material_slot_buttons.size()):
		var slot: Button = material_slot_buttons[i]
		_clear_tooltip(slot)
		if i < material_items.size():
			slot.text = _format_item_slot_text(material_items[i])
			slot.modulate = _get_quality_color(material_items[i])
			_bind_tooltip(slot, material_items[i])
		else:
			slot.text = _text("material_empty")
			slot.modulate = Color(0.75, 0.75, 0.75)
			_clear_tooltip(slot)

func _refresh_result_list() -> void:
	for child in result_list.get_children():
		child.queue_free()
	_add_result_line(_text("result_title"), true)
	var lines: Array = _get_result_lines()
	if lines.is_empty():
		_add_result_line(_text("result_empty"), false)
		return
	for line in lines:
		_add_result_line(str(line), false)

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
		_bind_tooltip(slot, item)
		inventory_grid.add_child(slot)

func _refresh_tabs() -> void:
	for tab_id in tab_buttons.keys():
		var button: Button = tab_buttons[tab_id] as Button
		if not button:
			continue
		button.button_pressed = tab_id == current_category

func _update_craft_button() -> void:
	craft_button.disabled = not _can_craft()
	if base_item.is_empty():
		_set_status(_text("status_select_base"))
	elif material_items.is_empty():
		_set_status(_text("status_need_material"))
	elif _can_craft():
		_set_status(_text("status_ready"))

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

func _refresh_pack_products() -> void:
	if not is_instance_valid(pack_row):
		return
	for child in pack_row.get_children():
		child.queue_free()
	for pack in map_pack_products:
		var button: Button = _make_pack_button(pack)
		pack_row.add_child(button)

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

func _sort_items_by_name(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("name", "")) < str(b.get("name", ""))

func _close_open_pack_overlay() -> void:
	for item in pending_open_pack_items:
		_return_item_to_inventory(item)
	pending_open_pack_items.clear()
	open_pack_overlay.visible = false
	_hide_tooltip()
	_refresh_all()

func _play_gold_cost_fly_text(source: Control, price: int) -> void:
	var label: Label = Label.new()
	label.text = "-%d" % price
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = Color(1.0, 0.35, 0.2)
	fly_text_layer.add_child(label)
	label.global_position = source.global_position + source.size * 0.5
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", gold_label.global_position + gold_label.size * 0.5, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(label.queue_free)

func _update_gold_label() -> void:
	if is_instance_valid(gold_label):
		gold_label.text = _text("gold") % gold

func _move_item_to_base(item_data: Dictionary) -> void:
	_take_item_from_inventory(item_data)
	base_item = item_data.duplicate(true)
	base_item["count"] = 1
	item_added_to_table.emit(base_item)
	_refresh_all()

func _add_material(item_data: Dictionary) -> void:
	if material_items.size() >= max_material_slots:
		_set_status(_text("status_no_slot"))
		return
	_take_item_from_inventory(item_data)
	var table_item: Dictionary = item_data.duplicate(true)
	table_item["count"] = 1
	material_items.append(table_item)
	item_added_to_table.emit(table_item)
	_refresh_all()

func _can_use_as_base(item_data: Dictionary) -> bool:
	if base_filter.is_valid():
		return bool(base_filter.call(item_data))
	return bool(item_data.get("is_base", false))

func _can_use_as_material(item_data: Dictionary) -> bool:
	if base_item.is_empty():
		return false
	if material_filter.is_valid():
		return bool(material_filter.call(base_item, item_data))
	return bool(item_data.get("is_material", true))

func _can_craft() -> bool:
	return not base_item.is_empty() and not material_items.is_empty()

func _make_craft_result() -> Dictionary:
	if craft_handler.is_valid():
		var handled_result: Variant = craft_handler.call(base_item, material_items)
		if handled_result is Dictionary:
			return handled_result
	crafted_count += 1
	var result: Dictionary = base_item.duplicate(true)
	result["name"] = "%s +%d" % [str(base_item.get("name", "Result")), material_items.size()]
	result["description"] = "由当前基底和材料临时合成的调试结果。"
	result["props"] = _merge_props(base_item, material_items)
	result["instance_id"] = "%s_crafted_%d" % [str(base_item.get("id", "item")), crafted_count]
	result["count"] = 1
	return result

func _get_result_lines() -> Array:
	if base_item.is_empty():
		return []
	if result_preview_provider.is_valid():
		var preview: Variant = result_preview_provider.call(base_item, material_items)
		if preview is Array:
			return preview
	var lines: Array = []
	lines.append("基底：%s" % str(base_item.get("name", "-")))
	lines.append("材料数量：%d" % material_items.size())
	var props: Dictionary = _merge_props(base_item, material_items)
	for key in props.keys():
		lines.append("%s：%s" % [str(key), str(props[key])])
	return lines

func _merge_props(source_base: Dictionary, source_materials: Array) -> Dictionary:
	var result: Dictionary = {}
	var base_props: Dictionary = source_base.get("props", {}) as Dictionary
	for key in base_props.keys():
		result[key] = base_props[key]
	for item in source_materials:
		var props: Dictionary = item.get("props", {}) as Dictionary
		for key in props.keys():
			if result.has(key) and result[key] is int and props[key] is int:
				result[key] += props[key]
			else:
				result[key] = props[key]
	return result

func _take_item_from_inventory(item_data: Dictionary) -> void:
	var item_key: String = _get_item_key(item_data)
	for item in inventory_items:
		if _get_item_key(item) == item_key:
			item["count"] = max(0, _get_item_count(item) - 1)
			return

func _return_item_to_inventory(item_data: Dictionary) -> void:
	var item_key: String = _get_item_key(item_data)
	for item in inventory_items:
		if _get_item_key(item) == item_key:
			item["count"] = _get_item_count(item) + 1
			return
	var returned_item: Dictionary = item_data.duplicate(true)
	returned_item["count"] = 1
	inventory_items.append(returned_item)

func _make_slot_button(label_text: String, show_hover: bool) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.custom_minimum_size = slot_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	if not show_hover:
		button.mouse_filter = Control.MOUSE_FILTER_PASS
	return button

func _bind_tooltip(slot: Control, item_data: Dictionary) -> void:
	slot.mouse_entered.connect(_show_tooltip_for_slot.bind(slot, item_data))
	slot.mouse_exited.connect(_hide_tooltip)

func _clear_tooltip(slot: Control) -> void:
	for connection in slot.mouse_entered.get_connections():
		slot.mouse_entered.disconnect(connection.callable)
	for connection in slot.mouse_exited.get_connections():
		slot.mouse_exited.disconnect(connection.callable)

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

func _hide_tooltip() -> void:
	tooltip_panel.visible = false

func _set_tooltip_line_limits(desc_lines: int, props_lines: int) -> void:
	tooltip_desc.max_lines_visible = desc_lines
	tooltip_props.max_lines_visible = props_lines

func _place_tooltip(slot: Control) -> void:
	var screen_rect: Rect2 = Rect2(Vector2.ZERO, get_viewport_rect().size)
	_place_item_tooltip_top_aligned(slot, screen_rect, tooltip_max_size)

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

func _apply_tooltip_content_size(max_size_value: Vector2) -> void:
	var desired_size: Vector2 = _measure_tooltip_content_size(max_size_value)
	tooltip_panel.custom_minimum_size = desired_size
	tooltip_panel.size = desired_size

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

func _add_result_line(text_value: String, is_title: bool) -> void:
	var label: Label = Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_title:
		label.add_theme_font_size_override("font_size", 22)
	result_list.add_child(label)

func _format_item_slot_text(item_data: Dictionary) -> String:
	var count: int = _get_item_count(item_data)
	if count > 1:
		return "%s\nx%d" % [str(item_data.get("name", "-")), count]
	return str(item_data.get("name", "-"))

func _format_props(props: Variant) -> String:
	if not (props is Dictionary):
		return ""
	var lines: Array[String] = []
	for key in props.keys():
		lines.append("%s：%s" % [str(key), str(props[key])])
	return "\n".join(lines)

func _limit_text(text_value: String, max_length: int) -> String:
	if text_value.length() <= max_length:
		return text_value
	return text_value.substr(0, max_length) + "..."

func _get_item_count(item_data: Dictionary) -> int:
	return int(item_data.get("count", 1))

func _get_item_key(item_data: Dictionary) -> String:
	var instance_id: String = str(item_data.get("instance_id", ""))
	if not instance_id.is_empty():
		return instance_id
	return str(item_data.get("id", ""))

func _is_item_in_category(item_data: Dictionary, category: String) -> bool:
	if category == CATEGORY_ALL:
		return true
	return str(item_data.get("category", "")) == category

func _get_type_text(category: String) -> String:
	match category:
		CATEGORY_EQUIPMENT:
			return _text("equipment")
		CATEGORY_MAP:
			return _text("map")
		CATEGORY_MATERIAL:
			return _text("material")
	return _text("all")

func _get_quality_color(item_data: Dictionary) -> Color:
	match str(item_data.get("quality", "common")):
		"rare":
			return Color.CORNFLOWER_BLUE
		"epic":
			return Color.PURPLE
		"legendary":
			return Color.ORANGE
	return Color.WHITE

func _set_status(text_value: String) -> void:
	status_label.text = text_value

func _emit_table_changed() -> void:
	workbench_changed.emit(base_item, material_items)

func _text(key: String) -> String:
	return str(TEXT.get(key, key))

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
		items.append({
			"id": item_id,
			"name": _csv_value(line, col, "name"),
			"category": category,
			"map_category": raw_category,
			"quality": _csv_value(line, col, "quality").to_lower(),
			"description": _csv_value(line, col, "description"),
			"count": max(1, _csv_value(line, col, "count").to_int()),
			"is_base": _parse_bool(_csv_value(line, col, "is_base")),
			"is_material": _parse_bool(_csv_value(line, col, "is_material")),
			"is_map_element": is_map_element,
			"pack_probability": _csv_value(line, col, "pack_probability").to_float(),
			"props": _parse_props(_csv_value(line, col, "props"))
		})
	return items

func _map_csv_header(header: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for i in range(header.size()):
		result[str(header[i]).strip_edges()] = i
	return result

func _csv_value(line: PackedStringArray, col: Dictionary, key: String) -> String:
	if not col.has(key):
		return ""
	var index: int = int(col[key])
	if index < 0 or index >= line.size():
		return ""
	return str(line[index]).strip_edges()

func _should_skip_config_row(item_id: String) -> bool:
	return item_id.is_empty() or item_id.begins_with("__") or item_id.begins_with("#")

func _parse_bool(value: String) -> bool:
	var text: String = value.strip_edges().to_upper()
	return text == "TRUE" or text == "1" or text == "YES" or text == "是"

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
