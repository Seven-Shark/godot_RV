extends Label

## 调试信息显示脚本
## 挂载在 Label 上，用于实时显示 FPS 和内存占用

func _process(delta: float) -> void:
	# 1. 获取帧率
	var fps = Engine.get_frames_per_second()
	
	# 2. 获取静态内存占用 (单位转为 MB)
	var memory_mb = OS.get_static_memory_usage() / 1024.0 / 1024.0
	
	# 3. 获取显存占用 (可选，单位转为 MB)
	# 注意：Render Video Mem 包含纹理、网格等显存占用
	var video_mem_mb = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1024.0 / 1024.0
	
	# 4. 获取对象数量 (可选，监控是否有对象泄漏)
	var object_count = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# 5. 格式化文本
	text = "FPS: %d\nMem: %.2f MB\nVRAM: %.2f MB\nObjs: %d" % [fps, memory_mb, video_mem_mb, object_count]

	# 6. 根据 FPS 变色 (可选优化体验)
	if fps >= 55:
		modulate = Color.GREEN # 流畅
	elif fps >= 30:
		modulate = Color.YELLOW # 一般
	else:
		modulate = Color.RED    # 卡顿
