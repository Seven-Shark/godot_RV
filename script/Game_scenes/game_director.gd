extends Node2D
class_name GameDirector

## 探险导演系统 (GameDirector)
## 职责：纯粹的“探险副本时间/波次控制器”。
## 特性：负责昼夜循环倒计时、阶段通知，并在探险结束（时间到或死亡）时通知 GameManager 返回家园。

#region 1. 信号定义
signal phase_changed(config: DayLoopConfig) ## 阶段切换信号 (通知 LevelManager 生成对应阶段物件)
signal time_updated(phase_index: int, time_remaining: float, phase_duration: float) ## 时间更新信号 (通知 HUD 刷新进度条)
#endregion

#region 2. 引用配置
@export_group("Systems")
@export var level_manager: LevelGenerator ## 关卡管理器 (用于获取玩家实例绑定死亡信号)
@export var game_hud: CanvasLayer ## 游戏 HUD 界面 (用于更新时间显示)
# [删除] ERS_Manager 被移除了，这里不再引用

@export_group("Cycle Config")
@export var day_phases: Array[DayLoopConfig] ## 昼夜循环阶段配置 (白天 -> 黄昏 -> 夜晚)
@export var infinite_cycle: bool = false ## 是否开启无限循环 (false 则在最后一阶段结束后返回家园)

@export_group("UI References")
@export var game_over_overlay: Control ## 游戏结束/胜利的通用遮罩层
@export var game_over_label: Label ## 遮罩层上的提示文本
# [删除] new_day_button 被移除了，结算直接用空格键
#endregion

#region 3. 内部状态变量
var is_waiting_for_return: bool = false ## 是否正在等待玩家按键返回家园
var is_victory: bool = false ## 记录本次探险是否为胜利结算
var current_phase_index: int = 0 ## 当前所处的阶段索引
var current_phase_timer: float = 0.0 ## 当前阶段剩余时间计时器
var is_cycle_active: bool = false ## 昼夜循环是否正在运行
#endregion

#region 4. 生命周期
## [初始化] 初始化状态，并开始探险循环
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # 确保暂停时 UI 也能继续响应
	
	_initialize_game_state()
	
	# 等待两帧，确保 LevelManager 等其他节点的 _ready 都执行完毕
	await get_tree().process_frame
	await get_tree().process_frame
	
	_connect_signals()
	_start_gameplay_loop()

## [物理帧] 处理昼夜循环计时逻辑
func _process(delta: float) -> void:
	if is_cycle_active and not get_tree().paused:
		_update_day_cycle(delta)

## [按键监听] 仅用于探险结束(胜利/死亡)后的返回家园操作
func _input(event: InputEvent) -> void:
	if is_waiting_for_return:
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			# [核心变动] 呼叫大管家，切换场景回家！
			GameManager.goto_home_scene(is_victory)
#endregion

#region 5. 初始化与信号连接
## [私有方法] 初始化 UI 和游戏暂停状态
func _initialize_game_state() -> void:
	if game_hud: game_hud.visible = true
	
	if game_over_overlay:
		game_over_overlay.visible = false
		game_over_overlay.modulate.a = 0.0
	
	get_tree().paused = false
	is_waiting_for_return = false

## [私有方法] 连接场景中各组件的信号
func _connect_signals() -> void:
	# 连接时间更新信号到 HUD
	if game_hud and game_hud.has_method("update_time_display"):
		if not time_updated.is_connected(game_hud.update_time_display):
			time_updated.connect(game_hud.update_time_display)
			
	# 连接玩家死亡信号
	if level_manager and level_manager.player:
		var player_node = level_manager.player
		if not player_node.on_dead.is_connected(_on_player_dead):
			player_node.on_dead.connect(_on_player_dead)
#endregion

#region 6. 昼夜循环核心逻辑
## [私有方法] 启动探险循环倒计时
func _start_gameplay_loop() -> void:
	is_cycle_active = true
	current_phase_index = 0
	
	# 初始化 HUD 的分段进度条结构
	if game_hud and game_hud.has_method("setup_day_cycle_ui"):
		game_hud.setup_day_cycle_ui(day_phases)
	
	# 启动第一阶段
	if not day_phases.is_empty():
		_start_phase(0)

## [私有方法] 更新当前阶段的倒计时并处理阶段切换
func _update_day_cycle(delta: float) -> void:
	if day_phases.is_empty(): return
	
	current_phase_timer -= delta
	var current_config = day_phases[current_phase_index]
	
	# 发送信号，供 DayCycleUI 更新分段进度条
	time_updated.emit(current_phase_index, current_phase_timer, current_config.duration)
	
	# 倒计时结束，进入下一阶段
	if current_phase_timer <= 0:
		_advance_to_next_phase()

## [私有方法] 推进到下一个阶段
func _advance_to_next_phase() -> void:
	current_phase_index += 1
	
	if current_phase_index >= day_phases.size():
		if infinite_cycle:
			current_phase_index = 0 # 循环回到第一阶段
			_start_phase(current_phase_index)
		else:
			_end_of_day_sequence() # [核心变动] 一天结束，进入胜利结算
	else:
		_start_phase(current_phase_index) 

## [私有方法] 启动指定索引的阶段
func _start_phase(index: int) -> void:
	if index >= day_phases.size(): return
	
	var config = day_phases[index]
	current_phase_timer = config.duration
	current_phase_index = index
	
	print(">>> [Director] 进入阶段: ", config.phase_name)
	phase_changed.emit(config) # 通知 LevelManager 生成该阶段的怪物/事件
#endregion

#region 7. 结算与结束流程 (胜利/阵亡)
## [胜利逻辑] 倒计时跑完，一天流程结束，触发胜利回城
func _end_of_day_sequence() -> void:
	print(">>> [Director] 探险倒计时结束，胜利通关！")
	is_cycle_active = false
	get_tree().paused = true # 暂停游戏，怪物停止移动
	is_victory = true
	_show_end_screen("探险成功！\n按空格键返回家园")

## [阵亡逻辑] 玩家血量归零，触发失败回城
func _on_player_dead() -> void:
	print(">>> [Director] 玩家死亡，探险失败...")
	is_cycle_active = false
	is_victory = false
	
	# 延迟 2 秒，让玩家看完死亡击飞动画
	await get_tree().create_timer(2.0, true, false, true).timeout
	
	get_tree().paused = true
	_show_end_screen("探险失败！\n按空格键返回家园")

## [视觉演出] 通用结束 UI (渐入黑屏与提示文字)
func _show_end_screen(msg: String) -> void:
	if game_over_overlay:
		game_over_overlay.visible = true
		game_over_overlay.modulate.a = 0.0
		
		if game_over_label:
			game_over_label.text = msg
		
		var tween = create_tween()
		# 强制 Tween 在游戏暂停时依然可以播放
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(game_over_overlay, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		await tween.finished
		is_waiting_for_return = true # 动画播完，允许玩家按空格
#endregion
