extends HBoxContainer
class_name DayCycleUI

var _bars: Array[ProgressBar] = [] 

func setup_bars(configs: Array[DayLoopConfig]):
	for child in get_children():
		child.queue_free()
	_bars.clear()
	
	for i in range(configs.size()):
		var bar = _create_single_bar(configs[i])
		add_child(bar)
		_bars.append(bar)

func _create_single_bar(config: DayLoopConfig) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL 
	bar.size_flags_vertical = Control.SIZE_FILL
	bar.size_flags_stretch_ratio = config.duration
	
	# 设置颜色样式
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = config.hud_color
	# 给一点边框，方便在黑色背景下看清
	style_fill.border_width_left = 1
	style_fill.border_color = Color(1, 1, 1, 0.1)
	
	bar.add_theme_stylebox_override("fill", style_fill)
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = config.duration
	bar.value = 0.0 
	
	return bar

func update_progress(current_phase_index: int, time_remaining: float, duration: float):
	if _bars.is_empty(): return
	
	for i in range(_bars.size()):
		var bar = _bars[i]
		if i < current_phase_index:
			bar.value = bar.max_value
		elif i > current_phase_index:
			bar.value = 0.0
		else:
			# 确保进度显示正确 (总长 - 剩余)
			bar.value = duration - time_remaining
