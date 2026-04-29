extends Button
class_name ERS_CardItem

## ERS 卡片实例节点
## 职责：承载单张卡牌展示（图标、名称、描述、价格）与购买后视觉状态。

#region 1. 节点引用
@onready var icon_rect: TextureRect = $VBoxContainer/Icon # 卡牌图标节点
@onready var name_label: Label = $VBoxContainer/NameLabel # 卡牌名称文本节点
@onready var desc_label: Label = $VBoxContainer/DescLabel # 卡牌描述文本节点
@onready var price_label: Label = $VBoxContainer/PriceLabel # 卡牌价格文本节点
#endregion

#region 2. 外部接口
# 根据卡牌数据刷新展示内容
func setup_card(data: ERS_CardData) -> void:
	if not data:
		return
	if icon_rect:
		icon_rect.texture = data.icon
	if name_label:
		name_label.text = data.card_name
	if desc_label:
		desc_label.text = data.description
	if price_label:
		price_label.text = "价格：%d" % data.price

# 设置购买后的视觉状态
func set_purchased_visual(is_purchased: bool) -> void:
	modulate.a = 0.3 if is_purchased else 1.0
#endregion
