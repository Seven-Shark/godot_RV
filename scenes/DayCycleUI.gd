extends HBoxContainer
class_name DayCycleUI

# 用来存那 3 个生成的进度条引用
var _bars: Array[TextureProgressBar] = []

## [初始化] Director 启动时调用这个，生成三段条
func setup_bars(configs: Array[DayLoopConfig]):
	# 1. 先把编辑器里可能存在的测试节点删干净
	for child in get_children():
		child.queue_free()
	_bars.clear()
	
	# 2. 遍历配置，动态生成进度条
	for config in configs:
		var bar = _create_single_bar(config)
		add_child(bar)
		_bars.append(bar)

## [内部方法] 创建单个阶段的进度条
func _create_single_bar(config: DayLoopConfig) -> TextureProgressBar:
	var bar = TextureProgressBar.new()
	
	# --- 核心布局设置 ---
	# 水平方向：既要填充(Fill)又要扩展(Expand)
	# 只有勾选了 Expand，下面的 Stretch Ratio 才会生效！
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL 
	bar.size_flags_vertical = Control.SIZE_FILL
	
	# 拉伸比例：直接使用阶段的时长
	# 比如白天30，夜晚60，那么夜晚的条就会比白天长一倍
	bar.size_flags_stretch_ratio = config.duration
	
	# --- 进度条数值 ---
	bar.min_value = 0.0
	bar.max_value = config.duration
	bar.step = 0.01
	bar.value = 0.0 # 初始为空
	
	# --- 颜色与纹理 ---
	# 创建一个 1x1 的纯白像素图，方便染色
	var placeholder = PlaceholderTexture2D.new()
	placeholder.size = Vector2(1, 1)
	bar.texture_progress = placeholder 
	
	# 染成配置里的颜色 (黄/深黄/蓝)
	bar.tint_progress = config.hud_color 
	
	return bar

## [更新] 每帧调用，更新进度条的填充情况
func update_progress(current_phase_index: int, time_remaining: float, duration: float):
	if _bars.is_empty(): return
	
	for i in range(_bars.size()):
		var bar = _bars[i]
		
		if i < current_phase_index:
			# 之前的阶段：保持填满状态
			bar.value = bar.max_value
			
		elif i > current_phase_index:
			# 未来的阶段：保持空状态
			bar.value = 0.0
			
		else:
			# 当前阶段：计算填充进度
			# Director 传来的 time_remaining 是倒计时 (30 -> 0)
			# 进度条通常是从左往右涨 (0 -> 30)，所以用 duration - remaining
			bar.value = duration - time_remaining
