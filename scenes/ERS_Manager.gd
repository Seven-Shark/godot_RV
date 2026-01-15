extends CanvasLayer
class_name ERS_Manager

#region 信号定义
signal start_next_day_requested(purchased_objects: Array[PackedScene]) ## 请求进入下一天，并携带购买的物件列表
#endregion

#region 配置引用
@export var available_cards: Array[ERS_CardData] = [] ## 卡池：所有可能出现的卡牌
@export var card_container: HBoxContainer ## UI容器：用来放三张卡牌的父节点
@export var next_day_button: Button ## UI按钮：进入下一天
@export var player_wallet: StatsComponent ## 引用玩家的数据组件(扣钱用)，或者你可以写个单例 Global.gold
#endregion

#region 内部状态
var current_purchased_objects: Array[PackedScene] = [] ## 玩家本轮已购买的物件预制体
var selected_cards_data: Array[ERS_CardData] = [] ## 当前展示的三张卡数据
#endregion

func _ready() -> void:
	visible = false # 默认隐藏
	next_day_button.pressed.connect(_on_next_day_button_pressed)

# --- 核心功能 1：打开 ERS 界面 ---
func open_ers_shop():
	print(">>> 打开 ERS 商店")
	visible = true
	get_tree().paused = true # 暂停游戏
	
	current_purchased_objects.clear() # 清空上一轮的购买记录
	_generate_random_cards()

# --- 核心功能 2：随机抽取卡牌 ---
func _generate_random_cards():
	# 清空旧的 UI 卡牌
	for child in card_container.get_children():
		child.queue_free()
	
	selected_cards_data.clear()
	
	# 简单的随机抽取 3 张 (允许重复，或者你可以写逻辑去重)
	for i in range(3):
		if available_cards.is_empty(): break
		var random_card = available_cards.pick_random()
		selected_cards_data.append(random_card)
		
		# 创建卡牌 UI (假设你有一个 CardUI 的预制体，或者直接用代码生成按钮)
		_create_card_ui(random_card, i)

# --- 核心功能 3：创建卡牌 UI ---
# 这里为了演示简单，直接用 Button，建议你做一个专门的 ERS_CardUI.tscn
func _create_card_ui(data: ERS_CardData, index: int):
	var btn = Button.new()
	btn.text = "%s\n$%d" % [data.card_name, data.price]
	btn.icon = data.icon
	btn.custom_minimum_size = Vector2(150, 200)
	
	# 连接购买信号
	btn.pressed.connect(func(): _on_card_purchased(data, btn))
	
	card_container.add_child(btn)

# --- 核心功能 4：购买逻辑 ---
func _on_card_purchased(data: ERS_CardData, btn_node: Button):
	# 检查钱够不够 (假设 StatsComponent 有 current_gold 属性)
	# if player_wallet.current_gold >= data.price:
	# 	player_wallet.consume_gold(data.price)
	
	print("购买了: ", data.card_name)
	current_purchased_objects.append(data.object_prefab)
	
	# 视觉反馈：变灰或消失，防止重复购买
	btn_node.disabled = true
	btn_node.text = "已购买"

# --- 核心功能 5：进入下一天 ---
func _on_next_day_button_pressed():
	print(">>> ERS 结束，进入下一天")
	visible = false
	get_tree().paused = false # 恢复游戏
	
	# 发送信号给 LevelManager，把买到的东西传过去
	start_next_day_requested.emit(current_purchased_objects)
