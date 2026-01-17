extends CanvasLayer
class_name ERS_Manager

#region 信号定义
signal start_next_day_requested(purchased_objects: Array[PackedScene]) ## 请求进入下一天，并携带购买的物件列表
#endregion

#region 配置引用
@export var available_cards: Array[ERS_CardData] = [] ## 卡池：所有可能出现的卡牌
@export var card_container: HBoxContainer ## UI容器：用来放三张卡牌的父节点
@export var next_day_button: Button ## UI按钮：进入下一天
@export var wallet_label: Label ## [新增] 显示持有金币的 Label，请在编辑器里拖进来
# @export var player_wallet: StatsComponent <--- 已删除，改用全局 GameDataManager
#endregion

#region 内部状态
var current_purchased_objects: Array[PackedScene] = [] ## 玩家本轮已购买的物件预制体
var selected_cards_data: Array[ERS_CardData] = [] ## 当前展示的三张卡数据
#endregion

func _ready() -> void:
	visible = false # 默认隐藏
	next_day_button.pressed.connect(_on_next_day_button_pressed)
	
	# [新增] 连接全局金币变化信号，实时刷新界面
	# 确保你已经创建了 GameDataManager 这个 Autoload 脚本
	if GameDataManager:
		GameDataManager.gold_changed.connect(_update_wallet_ui)
		# 初始化显示一次当前金币
		_update_wallet_ui(GameDataManager.current_gold)

# --- 核心功能 1：打开 ERS 界面 ---
func open_ers_shop():
	print(">>> 打开 ERS 商店")
	
	visible = true
	
	current_purchased_objects.clear() # 清空上一轮的购买记录
	_generate_random_cards()

# [新增] 更新金币 UI 显示
func _update_wallet_ui(amount: int):
	if wallet_label:
		wallet_label.text = "持有金币: $%d" % amount

# --- 核心功能 2：随机抽取卡牌 ---
func _generate_random_cards():
	# 清空旧的 UI 卡牌
	for child in card_container.get_children():
		child.queue_free()
	
	selected_cards_data.clear()
	
	# 简单的随机抽取 3 张
	for i in range(3):
		if available_cards.is_empty(): break
		var random_card = available_cards.pick_random()
		selected_cards_data.append(random_card)
		
		_create_card_ui(random_card, i)

# --- 核心功能 3：创建卡牌 UI ---
func _create_card_ui(data: ERS_CardData, index: int):
	var btn = Button.new()
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	# 设置按钮文本和图标
	btn.text = "%s\n$%d" % [data.card_name, data.price]
	btn.icon = data.icon
	# 设置固定大小，确保布局整齐
	btn.custom_minimum_size = Vector2(150, 200)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	
	# 连接购买信号
	btn.pressed.connect(func(): _on_card_purchased(data, btn))
	
	card_container.add_child(btn)

# --- 核心功能 4：购买逻辑 (修改版) ---
func _on_card_purchased(data: ERS_CardData, btn_node: Button):
	# 1. 调用全局管理器尝试扣款
	var is_success = false
	if GameDataManager:
		is_success = GameDataManager.try_spend_gold(data.price)
	
	if is_success:
		print("购买成功: ", data.card_name)
		
		# 2. 记录购买物品
		current_purchased_objects.append(data.object_prefab)
		
		# 3. [关键修改] 让卡牌“消失”但保留占位
		# 禁用按钮，防止再次点击
		btn_node.disabled = true
		# 将透明度设为 0 (完全隐形)
		# 我们不使用 visible = false，因为那会导致右边的卡牌挤过来，破坏布局
		btn_node.modulate.a = 0.0 
		
	else:
		# 4. 购买失败反馈 (闪烁红色)
		print("金币不足！")
		var original_modulate = btn_node.modulate
		var tween = create_tween()
		tween.tween_property(btn_node, "modulate", Color.RED, 0.1)
		tween.tween_property(btn_node, "modulate", original_modulate, 0.1)

# --- 核心功能 5：进入下一天 ---
func _on_next_day_button_pressed():
	print(">>> ERS 结束，进入下一天")	
	# 发送信号给 LevelManager，把买到的东西传过去
	start_next_day_requested.emit(current_purchased_objects)
