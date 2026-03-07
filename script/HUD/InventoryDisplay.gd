extends HBoxContainer

@export var slot_prefab: PackedScene ## InventorySlot.tscn

func _ready() -> void:
	# 监听背包更新
	GameDataManager.inventory_full_update.connect(_on_inventory_update)
	# 初始更新
	_on_inventory_update(GameDataManager.inventory)

func _on_inventory_update(inventory: Dictionary) -> void:
	# 清空旧显示
	for child in get_children():
		child.queue_free()
	
	# 重新生成
	for item_id in inventory:
		var data = inventory[item_id]
		var item = data["item"] as ItemData
		var count = data["count"] as int
		
		if count > 0:
			var slot = slot_prefab.instantiate()
			add_child(slot)
			if slot.has_method("setup"):
				slot.setup(item, count)
