extends Node2D

#region 引用配置
@export_group("References")
@export var tile_map: TileMapLayer ## 引用你的地图层
@export var player: CharacterBase ## 引用你的玩家
@export var object_container: Node2D ## 专门用来装生成物件的父节点（方便一键清空）
@export var spawnable_objects: Array[PackedScene] ## 拖入树木、石头等预制体

@export_group("Generation Config")
@export var spawn_config_list: Array[SpawnData] ## 拖入你创建的资源配置数据列表
@export var safe_zone_radius: int = 5 ## 安全区半径，中心点周围多少格内不生成物件
#endregion

#region 节点引用
@onready var new_day_button: Button = $"../GameHUD/NewDayButton" ## 开启新一天的按钮引用
@onready var hud: CanvasLayer = $"../GameHUD" ## HUD界面引用
#endregion

#region 内部变量
var current_objects: Array[Node] = [] ## 用于存储当前生成的物件引用的缓存数组
#endregion

#region 生命周期
# 节点初始化，设置随机数、连接信号并初始化游戏状态
func _ready() -> void:
	# 确保随机数种子不同
	randomize()
	# 连接按钮点击信号
	if new_day_button:
		new_day_button.pressed.connect(_on_new_day_pressed)
	
	# 游戏开始时也可以自动生成一次（可选）
	start_new_day()
	
	# 动态查找武器并连接 HUD 信号
	# 等待一帧，确保 Player 和内部的武器都初始化完毕
	await get_tree().process_frame
	
	if player and hud:
		# 尝试在 Player 下面找到引力枪
		# 路径是：Player -> WeaponAdmin -> WeaponCurrent -> Weapon_Gravitation
		var weapon_node = player.get_node_or_null("WeaponAdmin/WeaponCurrent/Weapon_Gravitation")
		
		if weapon_node:
			print("LevelManager: 成功连接 HUD 和 引力枪")
			hud.angle_changed.connect(weapon_node.set_attack_angle)
			hud.radius_changed.connect(weapon_node.set_attack_radius)
		else:
			# 如果没找到也不要崩溃，只是打印个警告
			push_warning("LevelManager: 在 Player 下没找到 Weapon_Gravitation，HUD 连接跳过。")
#endregion

#region 信号回调
# 点击“新的一天”按钮时的回调函数
func _on_new_day_pressed():
	start_new_day()
#endregion

#region 核心功能
# 开启新的一天：执行清理旧物件、重置玩家位置、生成新物件的完整流程
func start_new_day():
	print(">>> 开启新的一天：重置场景...")
	
	# 1. 清理旧物件
	_clear_objects()
	
	# 2. 获取地图中心点 (Grid 坐标)
	# 假设地图是填满的，我们取已使用矩形的中心，或者直接定为 (0,0)
	var map_rect = tile_map.get_used_rect()
	var center_cell = map_rect.get_center()
	
	# 3. 重置玩家位置
	_reset_player(center_cell)
	
	# 4. 生成新物件
	_spawn_new_objects(center_cell)

# [内部] 遍历并删除对象容器下的所有子节点，清空当前对象列表
func _clear_objects():
	# 遍历并删除容器下的所有子节点
	for child in object_container.get_children():
		child.queue_free()
	current_objects.clear()

# [内部] 将玩家位置重置到地图中心点的世界坐标，并归零速度
func _reset_player(center_cell: Vector2i):
	if player:
		# 将网格坐标转换为世界坐标，并加上半个格子的偏移(让玩家站在格子中心)
		# map_to_local 默认就是返回中心点
		var reset_pos = tile_map.map_to_local(center_cell)
		player.global_position = reset_pos
		player.velocity = Vector2.ZERO # 归零速度防止滑步
		print("玩家已重置到: ", reset_pos)

# [内部] 根据配置列表和安全区规则，在地图随机位置生成新物件
func _spawn_new_objects(center_cell: Vector2i):
	if spawn_config_list.is_empty():
		return

	# 1. 收集所有合法的生成点 (和之前一样)
	var valid_cells: Array[Vector2i] = []
	var used_cells = tile_map.get_used_cells()
	var safe_zone = Rect2i(
		center_cell.x - safe_zone_radius, 
		center_cell.y - safe_zone_radius, 
		safe_zone_radius * 2, 
		safe_zone_radius * 2
	)
	
	for cell in used_cells:
		if not safe_zone.has_point(cell):
			valid_cells.append(cell)
	
	# 2. 打乱位置，保证生成的物件分布是随机的
	valid_cells.shuffle()
	
	# 3. 开始按配置生成
	var current_cell_index = 0 # 记录用到第几个格子了
	
	for config in spawn_config_list:
		# 安全检查：配置是否有效
		if not config.object_prefab or config.spawn_count <= 0:
			continue
			
		# 循环生成指定数量
		for i in range(config.spawn_count):
			# 安全检查：如果没有格子可用了，就停止生成
			if current_cell_index >= valid_cells.size():
				push_warning("地图格子不够用了！停止生成。")
				return 
			
			# 取出一个格子坐标
			var cell = valid_cells[current_cell_index]
			current_cell_index += 1 # 索引+1，下一个物件用下一个格子
			
			# 实例化
			var world_pos = tile_map.map_to_local(cell)
			var obj_instance = config.object_prefab.instantiate()
			
			object_container.add_child(obj_instance)
			obj_instance.global_position = world_pos
			
	print("生成完毕，共使用了 ", current_cell_index, " 个格子")
#endregion
