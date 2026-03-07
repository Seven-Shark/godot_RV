extends Node

#region 信号定义
signal gold_changed(current_gold: int) ## 金币数量变化信号 (保留，可能用于商店)
signal inventory_changed(item: ItemData, current_count: int) ## 物品数量变化信号
signal inventory_full_update(items: Dictionary) ## 整个背包更新
#endregion

#region 数据存储
var current_gold: int = 500 ## 初始金币 500
# 核心背包数据: { "wood": {"item": ItemData, "count": 10}, "stone": ... }
# 键使用 item.id 字符串，方便快速查找
var inventory: Dictionary = {} 
#endregion

func _ready() -> void:
	# 稍微延迟一点广播初始值，确保 HUD 已经准备好接收
	await get_tree().process_frame
	gold_changed.emit(current_gold)
	inventory_full_update.emit(inventory)

# --- 功能 1: 增加物品 (拾取时调用) ---
func add_item(item: ItemData, amount: int = 1):
	if not item: return
	
	if inventory.has(item.id):
		inventory[item.id]["count"] += amount
	else:
		inventory[item.id] = {
			"item": item,
			"count": amount
		}
	
	var current_count = inventory[item.id]["count"]
	print("获得物品: %s x%d (当前: %d)" % [item.item_name, amount, current_count])
	
	inventory_changed.emit(item, current_count)
	inventory_full_update.emit(inventory)

# --- 功能 2: 消耗物品 (合成/建造时调用) ---
func remove_item(item_id: String, amount: int = 1) -> bool:
	if not inventory.has(item_id):
		push_warning("尝试移除不存在的物品: " + item_id)
		return false
	
	if inventory[item_id]["count"] >= amount:
		inventory[item_id]["count"] -= amount
		var current_count = inventory[item_id]["count"]
		var item_ref = inventory[item_id]["item"]
		
		# 如果数量归零，是否移除条目？
		# 策略：如果完全用光，从背包移除，或者显示为0？
		# 为了UI稳定，通常显示为0或者移除。这里选择移除。
		if current_count <= 0:
			inventory.erase(item_id)
			inventory_changed.emit(item_ref, 0) # 通知变成了0
		else:
			inventory_changed.emit(item_ref, current_count)
			
		inventory_full_update.emit(inventory)
		return true
	else:
		push_warning("物品不足: %s (拥有 %d, 需要 %d)" % [item_id, inventory[item_id]["count"], amount])
		return false

# --- 功能 3: 检查物品数量 ---
func get_item_count(item_id: String) -> int:
	if inventory.has(item_id):
		return inventory[item_id]["count"]
	return 0

# --- 功能 4: 消费金币 (买卡时调用) ---
func try_spend_gold(amount: int) -> bool:
	if current_gold >= amount:
		current_gold -= amount
		gold_changed.emit(current_gold)
		return true
	else:
		print("金币不足！需要: %d, 持有: %d" % [amount, current_gold])
		return false
