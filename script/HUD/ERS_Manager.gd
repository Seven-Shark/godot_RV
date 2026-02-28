extends CanvasLayer
class_name ERS_Manager

## 环境重构管理器 (ERS_Manager)
## 职责：通用的卡牌抽取与购买界面。
## 场景兼容：支持在家园（作为出发前的整备）和探险中（作为中途奖励/商店）调用。

#region 1. 信号定义
## 当玩家按下确认/出发按钮时发出，携带本次选择/购买的所有物件列表
signal items_confirmed(purchased_objects: Array[PackedScene]) 
#endregion

#region 2. 配置引用
@export_group("UI Nodes")
@export var card_container: HBoxContainer ## 存放卡牌按钮的容器
@export var confirm_button: Button ## 确认/进入下一天按钮
@export var wallet_label: Label ## 显示金币的文本

@export_group("Data Asset")
@export var available_cards: Array[ERS_CardData] = [] ## 全体卡池配置
#endregion

#region 3. 内部状态
var current_purchased_objects: Array[PackedScene] = [] ## 本次打开界面期间购买的物件
var is_from_home: bool = true ## 内部标记：记录是从哪里打开的，用于改变按钮文字
#endregion

#region 4. 生命周期
## [初始化] 设置 UI 初始状态
func _ready() -> void:
	visible = false # 默认隐藏
	
	# 连接确认按钮
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	
	# 连接全局金币数据单例（假设你已创建 GameDataManager Autoload）
	if Engine.has_singleton("GameDataManager") or get_node_or_null("/root/GameDataManager"):
		var gdm = get_node("/root/GameDataManager")
		gdm.gold_changed.connect(_update_wallet_ui)
		_update_wallet_ui(gdm.current_gold)
#endregion

#region 5. 核心交互逻辑

## [公共方法] 开启 ERS 界面
## 参数 from_home: 是否从家园开启。如果是，按钮文字显示“开启探险”；否则显示“继续探险”。
func open_ers_shop(from_home: bool = true) -> void:
	self.is_from_home = from_home
	self.visible = true
	
	# 1. 根据来源更新按钮文字
	if confirm_button:
		confirm_button.text = "开启探险" if is_from_home else "继续探险"
	
	# 2. 清空本次缓存并生成新卡牌
	current_purchased_objects.clear()
	_generate_random_cards()
	
	# 3. 暂停游戏（如果是探险中途打开）
	get_tree().paused = true

## [私有方法] 随机抽取并创建卡牌 UI
func _generate_random_cards() -> void:
	# 清理旧卡牌
	for child in card_container.get_children():
		child.queue_free()
	
	# 随机抽取 3 张（逻辑简单处理，可后续优化为不重复抽取）
	var temp_pool = available_cards.duplicate()
	temp_pool.shuffle()
	
	for i in range(min(3, temp_pool.size())):
		_create_card_ui(temp_pool[i])

## [私有方法] 实例化单张卡牌按钮
func _create_card_ui(data: ERS_CardData) -> void:
	var btn = Button.new()
	# 确保按钮在暂停模式下也能点击
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	
	btn.text = "%s\n价格: %d" % [data.card_name, data.price]
	btn.icon = data.icon
	btn.custom_minimum_size = Vector2(180, 240)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	
	# 绑定购买匿名函数
	btn.pressed.connect(func(): _on_card_clicked(data, btn))
	
	card_container.add_child(btn)

## [私有方法] 处理点击卡牌后的购买逻辑
func _on_card_clicked(data: ERS_CardData, btn_node: Button) -> void:
	var gdm = get_node_or_null("/root/GameDataManager")
	if not gdm: return
	
	if gdm.try_spend_gold(data.price):
		# 购买成功
		print(">>> ERS: 购买成功 - ", data.card_name)
		current_purchased_objects.append(data.object_prefab)
		
		# 禁用并隐藏，保持布局
		btn_node.disabled = true
		btn_node.modulate.a = 0.3 # 变淡表示已买
	else:
		# 购买失败反馈
		_play_fail_effect(btn_node)

## [私有方法] 确认并关闭界面
func _on_confirm_pressed() -> void:
	self.visible = false
	get_tree().paused = false # 恢复游戏运行
	
	# 发出信号：我选完了，这些是我的战利品
	items_confirmed.emit(current_purchased_objects)
	
	# 如果是独立弹窗，确认后可以自我销毁，或者留给 GameManager 处理
	# queue_free() 
#endregion

#region 6. 辅助功能
## [辅助] 刷新金币显示
func _update_wallet_ui(amount: int) -> void:
	if wallet_label:
		wallet_label.text = "持有金币: %d" % amount

## [辅助] 购买失败的抖动或变色效果
func _play_fail_effect(node: Control) -> void:
	var tween = create_tween()
	tween.tween_property(node, "modulate", Color.RED, 0.05)
	tween.tween_property(node, "modulate", Color.WHITE, 0.05)
	print(">>> ERS: 金币不足！")
#endregion
