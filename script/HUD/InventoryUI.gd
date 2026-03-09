extends Control
class_name InventoryUI

## 合成与背包界面 (InventoryUI)
## 职责：管理配方列表显示、支持合成与建筑双标签页切换、处理长按合成与一键进入建造模式。

#region 1. 节点与资源引用
@export_group("UI References")
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var recipe_container: VBoxContainer = $ScrollContainer/RecipeList

@export_subgroup("Tabs")
@onready var tab_crafting: Label = $Tabs/VBoxContainer/CraftingLabel
@onready var tab_building: Label = $Tabs/VBoxContainer/BuildingLabel

@export_group("Prefabs & Data")
@export var recipe_row_prefab: PackedScene
@export var recipes: Array[CraftingRecipe] = [] ## 实际游戏中应由数据管家或数据库传入
#endregion

#region 2. 内部状态
var current_index: int = 0
var rows: Array[CraftingRecipeRow] = []

# Tab 状态：0 = 合成 (Crafting), 1 = 建筑 (Building)
var current_tab: int = 0 

# 合成进度状态
var is_holding_craft: bool = false
var craft_timer: float = 0.0
const CRAFT_TIME: float = 1.0 ## 默认合成所需时间 (秒)
#endregion

#region 3. 生命周期与初始化
func _ready() -> void:
	visible = false
	# [关键] 必须设置为 ALWAYS，否则暂停时无法接收输入和更新进度条
	process_mode = Node.PROCESS_MODE_ALWAYS 

	# 测试用：加载默认配方
	if recipes.is_empty():
		var test_recipes = ["Recipe_Stick", "Recipe_Wooden_Shield"]
		for r_name in test_recipes:
			var path = "res://script/Data/Recipes/" + r_name + ".tres"
			if FileAccess.file_exists(path):
				recipes.append(load(path))
	
	# 监听背包变化，以便实时更新配方状态（材料是否足够）
	if Engine.has_singleton("GameDataManager") or get_node_or_null("/root/GameDataManager"):
		GameDataManager.inventory_full_update.connect(_on_inventory_update)
	
	_populate_list()
	_update_selection()
	_update_tab_visuals()

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
		get_viewport().set_input_as_handled()
		return 
		
	# 如果背包没开，不处理后续逻辑，将按键还给游戏世界
	if not visible: return
	
	# 2. 向上/下切换配方 (W / S)
	if GameInputEvents.is_ui_up(event):
		change_selection(-1)
		get_viewport().set_input_as_handled() 
		
	elif GameInputEvents.is_ui_down(event):
		change_selection(1)
		get_viewport().set_input_as_handled()
		
	# 3. 左右切换标签页 (A / D)
	elif GameInputEvents.is_ui_left(event):
		_switch_tab(0)
		get_viewport().set_input_as_handled()
	elif GameInputEvents.is_ui_right(event):
		_switch_tab(1)
		get_viewport().set_input_as_handled()
		
	# 4. 按下确认 (E 键)
	elif GameInputEvents.is_interact_event(event):
		if current_tab == 1: 
			# 建筑模式：点按直接进入放置虚影模式
			_select_building()
		else: 
			# 合成模式：开始长按计时
			is_holding_craft = true
			craft_timer = 0.0
		get_viewport().set_input_as_handled()
		
	# 5. 松开确认 (E 键释放)
	elif GameInputEvents.is_interact_released(event):
		# 合成模式松开取消
		if current_tab == 0:
			is_holding_craft = false
			craft_timer = 0.0
			if rows.size() > current_index:
				rows[current_index].update_progress(0)
		get_viewport().set_input_as_handled()
#endregion

#region 5. 核心逻辑 (长按合成处理)
func _process(delta: float) -> void:
	# 仅在打开状态、且处于“合成 Tab”、且按住 E 键时执行
	if not visible or not is_holding_craft or current_tab != 0: return
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

#region 6. 核心逻辑 (选择建筑)
## [触发建筑] 选中建筑后，关闭界面并调用 Player 的 BuildComponent
func _select_building() -> void:
	if rows.size() <= current_index: return
	
	var row = rows[current_index]
	var recipe = row.recipe
	
	# 你可以选择在这里验证材料是否足够，或者留给 BuildComponent 验证
	if not row.can_craft():
		print(">>> [Inventory] 警告：材料不足，无法进入建造模式。")
		# return # 如果你想限制材料不足不能建造，取消这行的注释
	
	# 1. 找到玩家节点
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		push_warning(">>> [Inventory] 找不到 Player 节点，请确保玩家在 'Player' group 中。")
		return
		
	# 2. 获取建造组件
	var build_comp = player.get_node_or_null("BuildComponent")
	if not build_comp or not build_comp.has_method("enter_build_mode"):
		push_warning(">>> [Inventory] 玩家身上缺少有效的 BuildComponent 组件。")
		return
	
	# 3. 切换状态：关闭 UI，解除暂停，进入建造模式
	toggle_visibility()
	print(">>> [Inventory] 尝试调用 enter_build_mode...")
	build_comp.enter_build_mode(recipe)
	print(">>> [Inventory] 已传递建筑配方: ", recipe.result_item.item_name)
#endregion

#region 7. UI 渲染与视图控制
## [内部逻辑] 切换顶部标签页
func _switch_tab(tab_index: int) -> void:
	if current_tab == tab_index: return
	
	current_tab = tab_index
	current_index = 0 # 切换标签页时，重置列表焦点
	
	_populate_list()
	_update_selection()
	_update_tab_visuals()

## [内部逻辑] 改变标签页的高亮文字颜色
func _update_tab_visuals() -> void:
	if not tab_crafting or not tab_building: return
	
	if current_tab == 0:
		tab_crafting.modulate = Color.WHITE
		tab_building.modulate = Color(0.5, 0.5, 0.5)
	else:
		tab_crafting.modulate = Color(0.5, 0.5, 0.5)
		tab_building.modulate = Color.WHITE

## [内部逻辑] 动态生成配方列表 (支持 Tab 过滤)
func _populate_list() -> void:
	if not recipe_container or not recipe_row_prefab: return
	
	# 1. 清空当前列表
	for child in recipe_container.get_children():
		child.queue_free()
	rows.clear()
	
	# 2. 筛选符合当前 Tab 的配方
	var filtered_recipes = []
	for r in recipes:
		if not r or not r.result_item: continue
		var is_building = (r.result_item.item_type == ItemData.ItemType.BUILDABLE)
		
		# Tab 0 只要非建筑，Tab 1 只要建筑
		if current_tab == 0 and not is_building:
			filtered_recipes.append(r)
		elif current_tab == 1 and is_building:
			filtered_recipes.append(r)
			
	# 3. 生成新 UI
	for r in filtered_recipes:
		var row = recipe_row_prefab.instantiate() as CraftingRecipeRow
		recipe_container.add_child(row)
		row.setup(r)
		rows.append(row)

func _refresh_all_rows() -> void:
	for row in rows:
		if row.has_method("refresh_ingredients"):
			row.refresh_ingredients() 

## [导航] 改变选中项并自动滚动 (支持安全循环)
func change_selection(dir: int) -> void:
	if rows.is_empty(): return
	
	# 循环选择算法
	current_index += dir
	if current_index < 0: 
		current_index = rows.size() - 1
	elif current_index >= rows.size(): 
		current_index = 0
		
	_update_selection()

func _update_selection() -> void:
	for i in range(rows.size()):
		if rows[i].has_method("set_selected"):
			rows[i].set_selected(i == current_index)
			
	if rows.size() > 0:
		_ensure_visible()

## [UI 技巧] 保证当前选中的行在 ScrollContainer 的可视范围内
func _ensure_visible() -> void:
	if scroll_container and rows.size() > current_index:
		var target_row = rows[current_index]
		scroll_container.ensure_control_visible(target_row)

## [公共接口] 切换背包显示状态与游戏暂停
func toggle_visibility() -> void:
	visible = not visible
	get_tree().paused = visible 
	if visible:
		# 每次打开时，重新加载数据以确保材料准确
		_populate_list() 
		_update_selection()
		_update_tab_visuals()
#endregion
