extends Node2D
class_name GameDirector

#region 引用配置
@export_group("Systems")
@export var level_manager: Node2D ## 引用 LevelManager (负责生成地图)
@export var ers_manager: ERS_Manager ## 引用 ERS 管理器 (负责商店)
@export var game_hud: CanvasLayer ## 引用 HUD (负责显示血条、按钮)

@export_group("UI References")
@export var new_day_button: Button ## 我们需要直接引用 HUD 里的按钮，以便在这里监听它的点击
#endregion

#region 生命周期
func _ready() -> void:
	# 1. 初始状态设置
	_initialize_game_state()
	
	# 2. 连接信号
	_connect_signals()
	
	# 3. 开始第一天 (不带任何额外物品)
	call_deferred("_start_gameplay_loop", [] as Array[PackedScene])

func _initialize_game_state():
	# 确保界面状态正确
	if ers_manager: ers_manager.visible = false
	if game_hud: game_hud.visible = true
	get_tree().paused = false

func _connect_signals():
	# 监听 HUD 的“新的一天”按钮 -> 进入商店流程
	if new_day_button:
		# 确保先断开其他地方的连接（防止多重触发），保持唯一性
		if new_day_button.pressed.is_connected(_on_new_day_button_pressed):
			new_day_button.pressed.disconnect(_on_new_day_button_pressed)
		new_day_button.pressed.connect(_on_new_day_button_pressed)
	
	# 监听 ERS 的“进入下一天”信号 -> 进入战斗流程
	if ers_manager:
		ers_manager.start_next_day_requested.connect(_on_ers_finished)
#endregion

#region 状态机：进入商店流程
# 当玩家点击 HUD 上的“新的一天”按钮时触发
func _on_new_day_button_pressed():
	print(">>> [Director] 阶段切换：进入 ERS 商店")
	
	# 1. 游戏暂停
	get_tree().paused = true
	
	# 2. UI 切换：隐藏 HUD
	if game_hud:
		game_hud.visible = false
		
	# 3. 数据处理：结算资源转金币 (将逻辑从 ERS 移交到这里，或者保留在 ERS 均可，建议这里统一调用)
	if GameDataManager:
		GameDataManager.convert_resources_to_gold()
	
	# 4. 唤起 ERS 界面
	if ers_manager:
		ers_manager.open_ers_shop()
#endregion

#region 状态机：进入战斗流程
# 当玩家在 ERS 界面点击“开始新的一天”后触发
func _on_ers_finished(purchased_objects: Array[PackedScene]):
	print(">>> [Director] 阶段切换：开始新的一天")
	
	# 1. 关闭 ERS 界面
	if ers_manager:
		ers_manager.visible = false
		
	# 2. UI 切换：显示 HUD
	if game_hud:
		game_hud.visible = true
	
	# 3. 游戏恢复
	get_tree().paused = false
	
	# 4. 通知 LevelManager 生成新关卡
	_start_gameplay_loop(purchased_objects)

# 执行实际的生成逻辑
func _start_gameplay_loop(extra_objects: Array[PackedScene]):
	if level_manager and level_manager.has_method("start_new_day"):
		level_manager.start_new_day(extra_objects)
#endregion
