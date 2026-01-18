extends Node

#region 信号定义
signal gold_changed(current_gold: int) ## 金币数量变化信号
signal temp_resource_changed(current_count: int) ## 临时资源变化信号
#endregion

#region 数据存储
var current_gold: int = 500 ## 初始金币 500
var temp_resources: int = 0 ## 当前关卡内收集的临时资源
#endregion

func _ready() -> void:
	# 稍微延迟一点广播初始值，确保 HUD 已经准备好接收
	await get_tree().process_frame
	gold_changed.emit(current_gold)

# --- 功能 1: 增加临时资源 (在关卡中拾取时调用) ---
func add_temp_resource(amount: int = 1):
	temp_resources += amount
	temp_resource_changed.emit(temp_resources)
	print("捡到资源！当前临时资源: ", temp_resources)

# --- 功能 2: 资源转金币 (进入 ERS 时调用) ---
func convert_resources_to_gold():
	if temp_resources > 0:
		var amount = temp_resources
		current_gold += amount
		temp_resources = 0 # 清零临时资源
		
		print("结算完成：将 %d 个资源转换为金币，当前总金币: %d" % [amount, current_gold])
		gold_changed.emit(current_gold)
		temp_resource_changed.emit(0)

# --- 功能 3: 消费金币 (买卡时调用) ---
func try_spend_gold(amount: int) -> bool:
	if current_gold >= amount:
		current_gold -= amount
		gold_changed.emit(current_gold)
		return true
	else:
		print("金币不足！需要: %d, 持有: %d" % [amount, current_gold])
		return false
