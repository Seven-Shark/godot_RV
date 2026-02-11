extends Node2D
class_name GameDirector

#region 引用配置
@export_group("Systems")
@export var level_manager: Node2D
@export var ers_manager: ERS_Manager
@export var game_hud: CanvasLayer

@export_group("UI References")
@export var new_day_button: Button
@export var game_over_overlay: Control
@export var game_over_label: Label
#endregion

#region 内部变量
var is_waiting_for_restart: bool = false
#endregion

#region 生命周期
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # 必须是 ALWAYS
	
	_initialize_game_state()
	_connect_signals()
	call_deferred("_start_gameplay_loop", [] as Array[PackedScene])

func _initialize_game_state():
	if ers_manager: ers_manager.visible = false
	if game_hud: game_hud.visible = true
	
	# 初始化隐藏死亡界面
	if game_over_overlay: 
		game_over_overlay.visible = false
		game_over_overlay.modulate.a = 0.0 # 透明度设为 0
	
	get_tree().paused = false
	is_waiting_for_restart = false

func _connect_signals():
	if new_day_button:
		if new_day_button.pressed.is_connected(_on_new_day_button_pressed):
			new_day_button.pressed.disconnect(_on_new_day_button_pressed)
		new_day_button.pressed.connect(_on_new_day_button_pressed)
	
	if ers_manager:
		if not ers_manager.start_next_day_requested.is_connected(_on_ers_finished):
			ers_manager.start_next_day_requested.connect(_on_ers_finished)
	
	if level_manager and "player" in level_manager and level_manager.player:
		var player_node = level_manager.player
		if not player_node.on_dead.is_connected(_on_player_dead):
			player_node.on_dead.connect(_on_player_dead)

# [空格键监听]
func _input(event: InputEvent) -> void:
	if is_waiting_for_restart:
		# 只响应空格键
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_restart_game()
#endregion

#region 状态机：进入商店/战斗流程 (保持不变)
func _on_new_day_button_pressed():
	print(">>> [Director] 进入 ERS")
	get_tree().paused = true
	if game_hud: game_hud.visible = false
	if GameDataManager: GameDataManager.convert_resources_to_gold()
	if ers_manager: ers_manager.open_ers_shop()

func _on_ers_finished(purchased_objects: Array[PackedScene]):
	print(">>> [Director] 开始新一天")
	if ers_manager: ers_manager.visible = false
	if game_hud: game_hud.visible = true
	get_tree().paused = false
	_start_gameplay_loop(purchased_objects)

func _start_gameplay_loop(extra_objects: Array[PackedScene]):
	if level_manager and level_manager.has_method("start_new_day"):
		level_manager.start_new_day(extra_objects)
	if level_manager and "player" in level_manager and level_manager.player:
		var player_node = level_manager.player
		if not player_node.on_dead.is_connected(_on_player_dead):
			player_node.on_dead.connect(_on_player_dead)
#endregion

#region 状态机：死亡流程 (核心修改)

func _on_player_dead():
	print(">>> [Director] 玩家死亡，播放演出...")
	
	# 1. 此时不要立刻暂停游戏 (paused = true)
	# 因为玩家需要 2秒钟时间播放掉落动画
	
	# 2. 等待 2 秒 (欣赏尸体飞出去)
	await get_tree().create_timer(2.0).timeout
	
	# 3. 2秒后，正式暂停游戏逻辑 (怪物停止，物理停止)
	get_tree().paused = true
	
	# 4. 渐现 UI
	_show_game_over_ui()

func _show_game_over_ui() -> void:
	if game_over_overlay:
		game_over_overlay.visible = true
		game_over_overlay.modulate.a = 0.0 # 确保起始透明
		
		if game_over_label:
			game_over_label.text = "按空格键开始下一天"
		
		# 使用 Tween 实现渐现 (0.5秒淡入)
		var tween = create_tween()
		tween.tween_property(game_over_overlay, "modulate:a", 1.0, 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		await tween.finished
		
		# 5. 允许玩家按空格
		is_waiting_for_restart = true

func _restart_game() -> void:
	print(">>> [Director] 重置场景")
	is_waiting_for_restart = false
	
	# 1. 先隐藏 UI
	if game_over_overlay:
		game_over_overlay.visible = false
		game_over_overlay.modulate.a = 0.0 
	
	# 2. [核心修改] 先解除暂停！让物理引擎恢复工作
	get_tree().paused = false
	
	# 3. [核心修改] 强制等待一帧物理帧
	# 这确保物理服务器已经准备好接收新的 Collision Layer 修改请求
	await get_tree().physics_frame
	
	# 4. 现在再去复活玩家，此时物理引擎是清醒的，Layer 修改一定会生效
	if level_manager and "player" in level_manager and level_manager.player:
		level_manager.player.reset_status()
	
	# 5. 最后重新生成场景
	_start_gameplay_loop([])
#endregion
