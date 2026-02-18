extends Node2D
class_name GameDirector

#region 1. 信号定义
signal phase_changed(config: DayLoopConfig) ## 阶段切换信号 (通知 GameManager 生成对应阶段物件)
## [修改] 时间更新信号：改为传递 (当前阶段索引, 剩余时间, 当前阶段总时长)
signal time_updated(phase_index: int, time_remaining: float, phase_duration: float) 
#endregion

#region 2. 引用配置
@export_group("Systems")
@export var level_manager: LevelManager ## 关卡管理器
@export var ers_manager: ERS_Manager ## 环境重构系统管理器
@export var game_hud: CanvasLayer ## 游戏 HUD 界面

@export_group("Cycle Config")
@export var day_phases: Array[DayLoopConfig] ## [核心] 昼夜循环阶段配置 (白天 -> 黄昏 -> 夜晚)
@export var infinite_cycle: bool = false ## 是否开启无限循环 (false 则在最后一阶段结束后进入 ERS)

@export_group("UI References")
@export var new_day_button: Button ## 开启新的一天/进入商店按钮
@export var game_over_overlay: Control ## 游戏结束遮罩层
@export var game_over_label: Label ## 游戏结束文本标签
#endregion

#region 3. 内部状态变量
var is_waiting_for_restart: bool = false ## 是否正在等待玩家按键重启
var current_phase_index: int = 0 ## 当前所处的阶段索引
var current_phase_timer: float = 0.0 ## 当前阶段剩余时间计时器
var is_cycle_active: bool = false ## 昼夜循环是否正在运行
#endregion

#region 4. 生命周期
## 初始化游戏状态并开始游戏循环
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # 确保暂停时仍能响应输入和逻辑
	
	_initialize_game_state()
	_connect_signals()
	
	# 开局延迟一帧启动游戏循环，确保所有节点已就绪
	call_deferred("_start_gameplay_loop", [] as Array[PackedScene])

## 处理昼夜循环计时逻辑
func _process(delta: float) -> void:
	if is_cycle_active and not get_tree().paused:
		_update_day_cycle(delta)

## 监听键盘输入 (仅用于死亡后的重启)
func _input(event: InputEvent) -> void:
	if is_waiting_for_restart:
		# 监听空格键
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_restart_game()
#endregion

#region 5. 初始化与信号连接
## 初始化 UI 和游戏暂停状态
func _initialize_game_state() -> void:
	if ers_manager: ers_manager.visible = false
	if game_hud: game_hud.visible = true
	
	# 隐藏死亡界面并重置透明度
	if game_over_overlay:
		game_over_overlay.visible = false
		game_over_overlay.modulate.a = 0.0
	
	get_tree().paused = false
	is_waiting_for_restart = false

## 连接场景中各组件的信号
func _connect_signals() -> void:
	if new_day_button:
		if new_day_button.pressed.is_connected(_on_new_day_button_pressed):
			new_day_button.pressed.disconnect(_on_new_day_button_pressed)
		new_day_button.pressed.connect(_on_new_day_button_pressed)
	
	if ers_manager:
		if not ers_manager.start_next_day_requested.is_connected(_on_ers_finished):
			ers_manager.start_next_day_requested.connect(_on_ers_finished)
	
	# 连接玩家死亡信号 (需确保 Player 节点存在)
	if level_manager and level_manager.player:
		var player_node = level_manager.player
		if not player_node.on_dead.is_connected(_on_player_dead):
			player_node.on_dead.connect(_on_player_dead)
#endregion

#region 6. 昼夜循环核心逻辑
## 更新当前阶段的倒计时并处理阶段切换
func _update_day_cycle(delta: float) -> void:
	if day_phases.is_empty(): return
	
	current_phase_timer -= delta
	
	var current_config = day_phases[current_phase_index]
	
	# [修改] 发送带 index 的信号，供 DayCycleUI 更新分段进度条
	time_updated.emit(current_phase_index, current_phase_timer, current_config.duration)
	
	# 倒计时结束，进入下一阶段
	if current_phase_timer <= 0:
		_advance_to_next_phase()

## 推进到下一个阶段
func _advance_to_next_phase() -> void:
	current_phase_index += 1
	
	if current_phase_index >= day_phases.size():
		if infinite_cycle:
			current_phase_index = 0 # 循环回到第一阶段
			_start_phase(current_phase_index)
		else:
			_end_of_day_sequence() # 一天结束，进入 ERS
	else:
		_start_phase(current_phase_index) # 进入下一阶段

## 启动指定索引的阶段
func _start_phase(index: int) -> void:
	if index >= day_phases.size(): return
	
	var config = day_phases[index]
	current_phase_timer = config.duration
	current_phase_index = index
	
	print(">>> [Director] 进入阶段: ", config.phase_name)
	
	# 通知 GameManager 生成该阶段的物件
	phase_changed.emit(config)

## 一天流程结束，强制进入 ERS 结算
func _end_of_day_sequence() -> void:
	print(">>> [Director] 倒计时结束，强制进入 ERS")
	is_cycle_active = false
	_on_new_day_button_pressed() # 复用按钮逻辑进入商店
#endregion

#region 7. 游戏流程控制 (ERS 与 循环)
## [UI回调] 玩家点击“结束一天”或倒计时结束，进入 ERS 商店
func _on_new_day_button_pressed() -> void:
	print(">>> [Director] 进入 ERS 结算")
	is_cycle_active = false # 停止计时
	get_tree().paused = true
	
	if game_hud: game_hud.visible = false
	if ers_manager: ers_manager.open_ers_shop()

## [ERS回调] 商店购物结束，开始新的一天
func _on_ers_finished(purchased_objects: Array[PackedScene]) -> void:
	print(">>> [Director] 商店购物结束，开始下一天")
	if ers_manager: ers_manager.visible = false
	if game_hud: game_hud.visible = true
	get_tree().paused = false
	
	_start_gameplay_loop(purchased_objects)

## 开始标准游戏循环 (重置地图并启动第一阶段)
func _start_gameplay_loop(extra_objects: Array[PackedScene]) -> void:
	is_cycle_active = true
	current_phase_index = 0
	
	# 1. 重置地图与生成基础环境 (传入商店购买物品)
	if level_manager:
		level_manager.start_new_day(extra_objects)
	
	# 2. [新增] 初始化 HUD 的分段进度条结构
	# 必须在开始计时前把配置传给 UI，让它生成对应的色块
	if game_hud and game_hud.has_method("setup_day_cycle_ui"):
		game_hud.setup_day_cycle_ui(day_phases)
	
	# 3. 启动第一阶段 (触发 phase_changed 生成第一波怪)
	if not day_phases.is_empty():
		_start_phase(0)
	
	# 4. 重新绑定玩家死亡信号 (因为玩家实例可能已重建)
	if level_manager and level_manager.player:
		if not level_manager.player.on_dead.is_connected(_on_player_dead):
			level_manager.player.on_dead.connect(_on_player_dead)
#endregion

#region 8. 死亡流程与重启
## [回调] 玩家死亡处理
func _on_player_dead() -> void:
	print(">>> [Director] 玩家死亡，播放演出...")
	
	# 延迟 2 秒暂停，播放死亡动画
	await get_tree().create_timer(2.0).timeout
	
	get_tree().paused = true
	_show_game_over_ui()

## 显示游戏结束 UI (渐入效果)
func _show_game_over_ui() -> void:
	if game_over_overlay:
		game_over_overlay.visible = true
		game_over_overlay.modulate.a = 0.0
		
		if game_over_label:
			game_over_label.text = "按空格键开始下一天"
		
		var tween = create_tween()
		tween.tween_property(game_over_overlay, "modulate:a", 1.0, 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		await tween.finished
		is_waiting_for_restart = true

## 重启游戏 (重置状态并开始新循环)
func _restart_game() -> void:
	print(">>> [Director] 重置场景")
	is_waiting_for_restart = false
	
	if game_over_overlay:
		game_over_overlay.visible = false
		game_over_overlay.modulate.a = 0.0
	
	# 先解除暂停，并等待一帧物理帧，确保状态重置生效
	get_tree().paused = false
	await get_tree().physics_frame
	
	if level_manager and level_manager.player:
		level_manager.player.reset_status()
	
	# 重新开始，不携带任何商店物品
	_start_gameplay_loop([])
#endregion
