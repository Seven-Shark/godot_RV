extends Control
class_name InventoryUI

## 合成与背包界面 (InventoryUI)
## 职责：管理配方列表显示、处理玩家的上下选择导航、以及长按合成/建造逻辑。

#region 1. 节点与资源引用
@export_group("UI References")
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var recipe_container: VBoxContainer = $ScrollContainer/RecipeList

@export_group("Prefabs & Data")
@export var recipe_row_prefab: PackedScene
@export var recipes: Array[CraftingRecipe] = [] ## 实际游戏中应由数据管家或数据库传入
#endregion

#region 2. 内部状态
var current_index: int = 0
var rows: Array[CraftingRecipeRow] = []

var is_holding_craft: bool = false
var craft_timer: float = 0.0
const CRAFT_TIME: float = 1.0 ## 默认合成所需时间 (秒)
#endregion

#region 3. 生命周期与初始化
func _ready() -> void:
	visible = false
	# [关键] 必须设置为 ALWAYS，否则暂停时无法接收输入和更新进度条
	process_mode = Node.PROCESS_MODE_ALWAYS 

	# 加载默认配方 (测试用)
	if recipes.is_empty():
		var stick_recipe = load("res://script/Data/Recipes/Recipe_Stick.tres")
		if stick_recipe:
			recipes.append(stick_recipe)
	
	# 监听背包变化，以便实时更新配方状态（材料是否足够）
	if Engine.has_singleton("GameDataManager") or get_node_or_null("/root/GameDataManager"):
		GameDataManager.inventory_full_update.connect(_on_inventory_update)
	
	_populate_list()
	_update_selection()

## [信号回调] 当背包数据发生变化时，刷新所有行的材料充足状态
func _on_inventory_update(_inventory: Dictionary) -> void:
	if visible:
		_refresh_all_rows()
#endregion

#region 4. 输入拦截与导航 (Input)
func _input(event: InputEvent) -> void:
	# 1. 优先检测打开/关闭背包
	if GameInputEvents.is_open_bag(event):
		toggle_visibility()
		get_viewport().set_input_as_handled() # 拦截 TAB 键
		return 
		
	# 如果背包没开，不处理后续逻辑，将按键还给游戏世界
	if not visible: return
	
	# 2. 向上切换 (W 键)
	if GameInputEvents.is_ui_up(event):
		change_selection(-1)
		get_viewport().set_input_as_handled() 
		
	# 3. 向下切换 (S 键)
	elif GameInputEvents.is_ui_down(event):
		change_selection(1)
		get_viewport().set_input_as_handled()
		
	# 4. 按下确认 / 开始长按建造 (E 键)
	elif GameInputEvents.is_interact_event(event):
		is_holding_craft = true
		craft_timer = 0.0
		get_viewport().set_input_as_handled()
		
	# 5. 松开确认 / 中断建造 (E 键释放)
	elif GameInputEvents.is_interact_released(event):
		is_holding_craft = false
		craft_timer = 0.0
		if rows.size() > current_index:
			rows[current_index].update_progress(0)
		get_viewport().set_input_as_handled()
#endregion

#region 5. 核心逻辑 (长按合成处理)
func _process(delta: float) -> void:
	if not visible or not is_holding_craft: return
	if rows.size() <= current_index: return
	
	var row = rows[current_index]
	
	if row.can_craft():
		craft_timer += delta
		var progress = (craft_timer / CRAFT_TIME) * 100.0
		row.update_progress(progress)
		
		# 达到合成时间，执行合成！
		if craft_timer >= CRAFT_TIME:
			_craft_item(row.recipe)
			craft_timer = 0.0
			row.update_progress(0)
			is_holding_craft = false 
	else:
		# 材料不足时，进度条归零
		craft_timer = 0.0
		row.update_progress(0)

## [执行合成] 扣除材料，增加产物
func _craft_item(recipe: CraftingRecipe) -> void:
	for stack in recipe.ingredients:
		GameDataManager.remove_item(stack.item.id, stack.count)
	
	GameDataManager.add_item(recipe.result_item, recipe.result_count)
	print(">>> [Inventory] 成功制作: " + recipe.result_item.item_name)
#endregion

#region 6. UI 渲染与视图控制
## [内部逻辑] 生成配方列表节点
func _populate_list() -> void:
	if not recipe_container or not recipe_row_prefab: return
	
	for child in recipe_container.get_children():
		child.queue_free()
	rows.clear()
	
	for recipe in recipes:
		if not recipe: continue
		var row = recipe_row_prefab.instantiate() as CraftingRecipeRow
		recipe_container.add_child(row)
		row.setup(recipe)
		rows.append(row)

func _refresh_all_rows() -> void:
	for row in rows:
		if row.has_method("refresh_ingredients"):
			row.refresh_ingredients() 

## [导航] 改变选中项并自动滚动
func change_selection(dir: int) -> void:
	if rows.is_empty(): return
	current_index = clamp(current_index + dir, 0, rows.size() - 1)
	_update_selection()
	_ensure_visible()

func _update_selection() -> void:
	for i in range(rows.size()):
		if rows[i].has_method("set_selected"):
			rows[i].set_selected(i == current_index)

## [UI 技巧] 保证当前选中的行在 ScrollContainer 的可视范围内
func _ensure_visible() -> void:
	if scroll_container and rows.size() > current_index:
		var target_row = rows[current_index]
		# Godot 4 的神级内置方法，自动计算并滚动到目标节点
		scroll_container.ensure_control_visible(target_row)

## [公共接口] 切换背包显示状态与游戏暂停
func toggle_visibility() -> void:
	visible = not visible
	get_tree().paused = visible 
	if visible:
		_refresh_all_rows()
#endregion
