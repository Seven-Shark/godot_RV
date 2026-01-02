extends Node2D

@export_group("References")
@export var tile_map: TileMapLayer  # 引用你的地图层
@export var player: CharacterBase   # 引用你的玩家
@export var object_container: Node2D # 专门用来装生成物件的父节点（方便一键清空）
@export var spawnable_objects: Array[PackedScene] # 拖入树木、石头等预制体

@export_group("Generation Config")
@export var spawn_config_list: Array[SpawnData] # 拖入你创建的资源
@export var safe_zone_radius: int = 5

@onready var new_day_button: Button = $"../HUD/NewDayButton"

# 用于存储当前生成的物件引用
var current_objects: Array[Node] = []

func _ready() -> void:
	# 确保随机数种子不同
	randomize()
	# 连接按钮点击信号
	new_day_button.pressed.connect(_on_new_day_pressed)
	
	# 游戏开始时也可以自动生成一次（可选）
	start_new_day()
	
func _on_new_day_pressed():
	start_new_day()

# --- 核心功能：新的一天 ---
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

# --- 逻辑 1: 清理 ---
func _clear_objects():
	# 遍历并删除容器下的所有子节点
	for child in object_container.get_children():
		child.queue_free()
	current_objects.clear()

# --- 逻辑 2: 重置玩家 ---
func _reset_player(center_cell: Vector2i):
	if player:
		# 将网格坐标转换为世界坐标，并加上半个格子的偏移(让玩家站在格子中心)
		# map_to_local 默认就是返回中心点
		var reset_pos = tile_map.map_to_local(center_cell)
		player.global_position = reset_pos
		player.velocity = Vector2.ZERO # 归零速度防止滑步
		print("玩家已重置到: ", reset_pos)

# --- 逻辑 3: 生成物件 ---
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
