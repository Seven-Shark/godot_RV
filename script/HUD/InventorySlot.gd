extends HBoxContainer
class_name InventorySlot

@onready var icon_rect: TextureRect = $Icon
@onready var count_label: Label = $Count

func setup(item: ItemData, count: int):
	if item and item.icon:
		icon_rect.texture = item.icon
		icon_rect.custom_minimum_size = Vector2(32, 32) # 设置一个合适的大小
	count_label.text = "x%d" % count
	
	# 如果数量为0，可能需要隐藏或移除，由父级控制
