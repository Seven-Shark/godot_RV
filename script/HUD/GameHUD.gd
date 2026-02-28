extends CanvasLayer

@onready var gold_label: Label = $GoldLabel
@onready var day_cycle_ui: HBoxContainer = $DayCyclePanel/Background/HBoxContainer


func _ready():
	
	# 连接全局信号
	GameDataManager.gold_changed.connect(_on_gold_changed)
	# 初始化显示
	_on_gold_changed(GameDataManager.current_gold)
	

# 2. [初始化] 接收配置并生成条
# 这个函数由 GameDirector 在 _start_gameplay_loop 里调用
func setup_day_cycle_ui(phases: Array[DayLoopConfig]):
	if day_cycle_ui:
		day_cycle_ui.setup_bars(phases)

# 3. [每帧更新] 接收时间并更新 UI
# 这个函数由 GameDirector 的 time_updated 信号连接触发
func update_time_display(phase_idx: int, remain: float, total: float):
	if day_cycle_ui:
		day_cycle_ui.update_progress(phase_idx, remain, total)

func _on_gold_changed(new_amount: int):
	if gold_label:
		gold_label.text = "Gold: %d" % new_amount
