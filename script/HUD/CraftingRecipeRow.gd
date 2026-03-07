extends PanelContainer
class_name CraftingRecipeRow

## 制作配方单行 UI (CraftingRecipeRow)
## 职责：展示单个合成配方的信息（图标、名字、品质、所需材料），并处理选中高亮与长按进度条更新。

#region 1. 节点引用
@onready var background: ColorRect = $Background
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var result_icon: TextureRect = $Content/ResultIcon
@onready var name_label: Label = $Content/InfoBox/NameLabel
@onready var quality_label: Label = $Content/InfoBox/QualityLabel
@onready var ingredients_container: HBoxContainer = $Content/IngredientsContainer
#endregion

#region 2. 内部状态
var recipe: CraftingRecipe
var is_selected: bool = false
#endregion

#region 3. 初始化配置
## [初始化] 接收配方数据并初始化 UI 显示
func setup(data: CraftingRecipe) -> void:
	recipe = data
	if not recipe or not recipe.result_item: return
	
	# 设置结果物品基本信息
	result_icon.texture = recipe.result_item.icon
	name_label.text = recipe.result_item.item_name
	
	# 设置品质文本与颜色
	var q_names = ["Common", "Rare", "Epic", "Legendary"]
	var q_idx = recipe.result_item.quality
	if q_idx >= 0 and q_idx < q_names.size():
		quality_label.text = q_names[q_idx]
	else:
		quality_label.text = "Unknown"
		
	quality_label.modulate = recipe.result_item.get_quality_color()
	
	# 刷新所需材料
	refresh_ingredients()
#endregion

#region 4. UI 刷新与状态更新
## [UI 更新] 刷新所需材料的图标与数量状态 (充足为绿，不足为红)
func refresh_ingredients() -> void:
	if not ingredients_container: return
	
	# 清理旧的材料节点
	for child in ingredients_container.get_children():
		child.queue_free()
		
	if not recipe: return
	
	# 动态生成新的材料节点
	for stack in recipe.ingredients:
		if not stack or not stack.item: continue
		
		var container = VBoxContainer.new()
		
		var icon = TextureRect.new()
		icon.texture = stack.item.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(32, 32)
		container.add_child(icon)
		
		var label = Label.new()
		var current = GameDataManager.get_item_count(stack.item.id)
		var required = stack.count
		label.text = "%d/%d" % [current, required]
		
		# 颜色反馈：足够为绿，不足为红
		if current >= required:
			label.modulate = Color.GREEN
		else:
			label.modulate = Color.RED
			
		container.add_child(label)
		ingredients_container.add_child(container)

## [视觉反馈] 设置当前行是否被玩家选中 (改变背景色)
func set_selected(selected: bool) -> void:
	is_selected = selected
	if not background: return
	
	if selected:
		background.color = Color(0.4, 0.4, 0.4, 0.9) # 选中高亮
	else:
		background.color = Color(0.1, 0.1, 0.1, 0.6) # 默认暗色

## [视觉反馈] 更新长按建造的进度条
func update_progress(value: float) -> void:
	if progress_bar:
		progress_bar.value = value
#endregion

#region 5. 逻辑校验
## [逻辑校验] 检查当前玩家背包内的材料是否满足该配方需求
func can_craft() -> bool:
	if not recipe: return false
	
	for stack in recipe.ingredients:
		if GameDataManager.get_item_count(stack.item.id) < stack.count:
			return false
	return true
#endregion
