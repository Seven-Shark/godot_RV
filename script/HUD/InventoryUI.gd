extends Control

@onready var recipe_container: VBoxContainer = $ScrollContainer/RecipeList
@onready var scroll_container: ScrollContainer = $ScrollContainer

@export var recipe_row_prefab: PackedScene
# List of recipes to display. In a real game, this might come from a database or manager.
@export var recipes: Array[CraftingRecipe] = [] 

var current_index: int = 0
var rows: Array[CraftingRecipeRow] = []

var is_holding_craft: bool = false
var craft_timer: float = 0.0
const CRAFT_TIME: float = 1.0 # Or use recipe specific time

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS 

	# Load recipes
	if recipes.is_empty():
		var stick_recipe = load("res://script/Data/Recipes/Recipe_Stick.tres")
		if stick_recipe:
			recipes.append(stick_recipe)
	
	# 监听背包变化，以便实时更新配方状态（材料是否足够）
	GameDataManager.inventory_full_update.connect(_on_inventory_update)
	
	_populate_list()
	_update_selection()

func _on_inventory_update(_inventory):
	if visible:
		_refresh_all_rows()

func _input(event: InputEvent) -> void:
	# 1. 优先检测打开/关闭背包 (修正了缺少 event 参数的 Bug)
	if GameInputEvents.is_open_bag(event):
		toggle_visibility()
		get_viewport().set_input_as_handled() # 拦截 TAB 键
		return # 切换完直接返回，不处理后续输入
		
	# 如果背包没开，就不处理下面的逻辑，把 W/S/E 还给玩家去走路和打怪
	if not visible: return
	
	# 2. 向上切换 (W 键)
	if GameInputEvents.is_ui_up(event):
		change_selection(-1)
		get_viewport().set_input_as_handled() # 拦截输入，防止游戏里的人物往上走
		
	# 3. 向下切换 (S 键)
	elif GameInputEvents.is_ui_down(event):
		change_selection(1)
		get_viewport().set_input_as_handled()
		
	# 4. 按下确认/开始长按建造 (E 键)
	elif GameInputEvents.is_interact_event(event):
		is_holding_craft = true
		craft_timer = 0.0
		get_viewport().set_input_as_handled()
		
	# 5. 松开确认/中断建造 (E 键释放)
	elif GameInputEvents.is_interact_released(event):
		is_holding_craft = false
		craft_timer = 0.0
		if rows.size() > current_index:
			rows[current_index].update_progress(0)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible: return
	
	if is_holding_craft and rows.size() > current_index:
		var row = rows[current_index]
		if row.can_craft():
			craft_timer += delta
			var progress = (craft_timer / CRAFT_TIME) * 100
			row.update_progress(progress)
			
			if craft_timer >= CRAFT_TIME:
				_craft_item(row.recipe)
				craft_timer = 0.0
				row.update_progress(0)
				is_holding_craft = false 
		else:
			craft_timer = 0.0
			row.update_progress(0)

func _craft_item(recipe: CraftingRecipe):
	# Consume ingredients
	for stack in recipe.ingredients:
		GameDataManager.remove_item(stack.item.id, stack.count)
	
	# Add result
	GameDataManager.add_item(recipe.result_item, recipe.result_count)
	
	print("Crafted: " + recipe.result_item.item_name)

func _populate_list():
	if not recipe_container: return
	
	for child in recipe_container.get_children():
		child.queue_free()
	rows.clear()
	
	for recipe in recipes:
		if not recipe: continue
		var row = recipe_row_prefab.instantiate() as CraftingRecipeRow
		recipe_container.add_child(row)
		row.setup(recipe)
		rows.append(row)

func _refresh_all_rows():
	for row in rows:
		row.refresh_ingredients() 

func change_selection(dir: int):
	if rows.is_empty(): return
	current_index = clamp(current_index + dir, 0, rows.size() - 1)
	_update_selection()
	_ensure_visible()

func _update_selection():
	for i in range(rows.size()):
		rows[i].set_selected(i == current_index)

func _ensure_visible():
	# Simple auto scroll logic
	if rows.size() > current_index:
		var row = rows[current_index]
		# Ensure the row is visible within scroll_container
		# This is a bit complex in Godot without built-in 'ensure_control_visible'
		# But ScrollContainer handles focus if we used focus, but we use manual selection.
		pass

func toggle_visibility():
	visible = !visible
	get_tree().paused = visible 
	if visible:
		_refresh_all_rows() # Open 时刷新一下状态
