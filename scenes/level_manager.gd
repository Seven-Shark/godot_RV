extends Node2D

#region 引用配置
@export_group("References")
@export var tile_map: TileMapLayer
@export var player: CharacterBase
@export var object_container: Node2D
@export var spawnable_objects: Array[PackedScene]

@export_group("Generation Config")
@export var spawn_config_list: Array[SpawnData]
@export var safe_zone_radius: int = 5

@export_group("Map Config")
@export var tile_source_id: int = 0

# --- 第一层：最外圈配置 (Outer Layer) ---
@export_subgroup("Outer Layer (Edges & Corners)")
@export var atlas_top_left: Vector2i = Vector2i(0, 0)
@export var atlas_top_right: Vector2i = Vector2i(2, 0)
@export var atlas_bottom_left: Vector2i = Vector2i(0, 2)
@export var atlas_bottom_right: Vector2i = Vector2i(2, 2)

@export var atlas_top_list: Array[Vector2i] = [Vector2i(1, 0)] 
@export var atlas_bottom_list: Array[Vector2i] = [Vector2i(1, 2)]
@export var atlas_left_list: Array[Vector2i] = [Vector2i(0, 1)]
@export var atlas_right_list: Array[Vector2i] = [Vector2i(2, 1)]

# --- 第二层：内圈配置 (Inner Layer) ---
@export_subgroup("Inner Layer (Row 2 / Col 2)")
@export var atlas_inner_top_list: Array[Vector2i] = [] 
@export var atlas_inner_bottom_list: Array[Vector2i] = []
@export var atlas_inner_left_list: Array[Vector2i] = []
@export var atlas_inner_right_list: Array[Vector2i] = []

# --- 第三层：中间填充图案配置 (Center Pattern) ---
# 修改点：不再只用一张图，而是定义一个矩形区域进行平铺
@export_subgroup("Center Pattern Loop")
@export var center_pattern_start: Vector2i = Vector2i(2, 2) ## 图案在Tileset的左上角坐标 (如 2,2)
@export var center_pattern_size: Vector2i = Vector2i(8, 8) ## 图案的长宽 (2到9一共是8格)
# 备用：如果计算出错时的默认单张图
@export var atlas_center_fallback: Vector2i = Vector2i(1, 1) 
#endregion

#region 节点引用
@onready var new_day_button: Button = $"../GameHUD/NewDayButton"
@onready var hud: CanvasLayer = $"../GameHUD"
# 注意：请确保这些路径在你的场景中是正确的，有时候层级变了路径会变
@onready var height_input: SpinBox = $"../GameHUD/NewDayButton/HeightInput"
@onready var width_input: SpinBox = $"../GameHUD/NewDayButton/WidthInput"

#endregion

#region 内部变量
var current_objects: Array[Node] = [] 
#endregion

#region 生命周期
func _ready() -> void:
	randomize()
	if new_day_button:
		new_day_button.pressed.connect(_on_new_day_pressed)
	
	start_new_day()
	
	await get_tree().process_frame
	if player and hud:
		var weapon_node = player.get_node_or_null("WeaponAdmin/WeaponCurrent/Weapon_Gravitation")
		if weapon_node:
			hud.angle_changed.connect(weapon_node.set_attack_angle)
			hud.radius_changed.connect(weapon_node.set_attack_radius)
#endregion

#region 信号回调
func _on_new_day_pressed():
	start_new_day()
#endregion

#region 核心功能
func start_new_day():
	print(">>> 开启新的一天...")
	
	var map_w = 20
	var map_h = 20
	
	# 添加安全检查，防止节点未连接导致报错
	if width_input: map_w = int(width_input.value)
	if height_input: map_h = int(height_input.value)
	
	_clear_objects()
	_generate_map_tiles(map_w, map_h)
	
	var map_rect = tile_map.get_used_rect()
	var center_cell = map_rect.get_center()
	
	_reset_player(center_cell)
	_spawn_new_objects(center_cell)

# 【核心修改】包含 双层边缘 + 中间8x8图案平铺 逻辑
func _generate_map_tiles(width: int, height: int):
	print("正在生成地图，尺寸: ", width, " x ", height)
	tile_map.clear()
	
	for x in range(width):
		for y in range(height):
			var grid_pos = Vector2i(x, y)
			var atlas_coord = atlas_center_fallback # 默认值
			
			# ==============================
			# 1. 第一层：最外圈 (Outer Layer)
			# ==============================
			if x == 0 or x == width - 1 or y == 0 or y == height - 1:
				if x == 0: 
					if y == 0: atlas_coord = atlas_top_left
					elif y == height - 1: atlas_coord = atlas_bottom_left
					else:
						var index = (y - 1) % atlas_left_list.size()
						atlas_coord = atlas_left_list[index]
				
				elif x == width - 1: 
					if y == 0: atlas_coord = atlas_top_right
					elif y == height - 1: atlas_coord = atlas_bottom_right
					else:
						var index = (y - 1) % atlas_right_list.size()
						atlas_coord = atlas_right_list[index]
				
				else: 
					if y == 0: 
						var index = (x - 1) % atlas_top_list.size()
						atlas_coord = atlas_top_list[index]
					elif y == height - 1:
						var index = (x - 1) % atlas_bottom_list.size()
						atlas_coord = atlas_bottom_list[index]

			# ==============================
			# 2. 第二层：内圈 (Inner Layer)
			# 排除四个内圈角落，角落留给中间逻辑填充，或者你可以专门定义内圈角
			# ==============================
			elif (x == 1 or x == width - 2 or y == 1 or y == height - 2) and width > 4 and height > 4:
				
				var is_inner_corner = (x == 1 and y == 1) or \
									  (x == width - 2 and y == 1) or \
									  (x == 1 and y == height - 2) or \
									  (x == width - 2 and y == height - 2)
				
				# 如果是内圈直线部分，且列表不为空，则使用内圈逻辑
				# 如果列表为空，则跳过这里，直接进入下方的 else (中间填充逻辑)
				var handled = false
				
				if not is_inner_corner:
					if x == 1 and not atlas_inner_left_list.is_empty():
						var index = (y - 2) % atlas_inner_left_list.size()
						atlas_coord = atlas_inner_left_list[index]
						handled = true
					elif x == width - 2 and not atlas_inner_right_list.is_empty():
						var index = (y - 2) % atlas_inner_right_list.size()
						atlas_coord = atlas_inner_right_list[index]
						handled = true
					elif y == 1 and not atlas_inner_top_list.is_empty():
						var index = (x - 2) % atlas_inner_top_list.size()
						atlas_coord = atlas_inner_top_list[index]
						handled = true
					elif y == height - 2 and not atlas_inner_bottom_list.is_empty():
						var index = (x - 2) % atlas_inner_bottom_list.size()
						atlas_coord = atlas_inner_bottom_list[index]
						handled = true
				
				# 如果没被内圈逻辑处理（比如是角落，或者列表为空），则当作中间块处理
				if not handled:
					atlas_coord = _get_center_pattern_coord(x, y)

			# ==============================
			# 3. 中间区域 (Center Pattern Fill)
			# ==============================
			else:
				# 调用新写的辅助函数来获取平铺坐标
				atlas_coord = _get_center_pattern_coord(x, y)

			# 最终设置
			tile_map.set_cell(grid_pos, tile_source_id, atlas_coord)

# 【新增辅助函数】计算中间图案的平铺坐标
func _get_center_pattern_coord(grid_x: int, grid_y: int) -> Vector2i:
	# 我们的中心区域实际上是从 grid (2, 2) 开始的
	# 因为 0 是外圈，1 是内圈（或者内圈角落）
	
	# 1. 计算相对偏移量 (Relative Offset)
	var offset_x = grid_x - 2
	var offset_y = grid_y - 2
	
	# 2. 确保偏移量为正数 (虽然在这个循环里肯定是正数，但为了健壮性)
	if offset_x < 0: offset_x = 0
	if offset_y < 0: offset_y = 0
	
	# 3. 对图案尺寸取余，实现循环
	var pattern_x = offset_x % center_pattern_size.x
	var pattern_y = offset_y % center_pattern_size.y
	
	# 4. 加上图案在 TileSet 里的起始坐标
	return center_pattern_start + Vector2i(pattern_x, pattern_y)

# [内部] 清理物件
func _clear_objects():
	for child in object_container.get_children():
		child.queue_free()
	current_objects.clear()

# [内部] 重置玩家
func _reset_player(center_cell: Vector2i):
	if player:
		var reset_pos = tile_map.map_to_local(center_cell)
		player.global_position = reset_pos
		player.velocity = Vector2.ZERO

# [内部] 生成物件
func _spawn_new_objects(center_cell: Vector2i):
	if spawn_config_list.is_empty(): return

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
	
	valid_cells.shuffle()
	
	var current_cell_index = 0
	
	for config in spawn_config_list:
		if not config.object_prefab or config.spawn_count <= 0: continue
			
		for i in range(config.spawn_count):
			if current_cell_index >= valid_cells.size(): return 
			
			var cell = valid_cells[current_cell_index]
			current_cell_index += 1
			
			var world_pos = tile_map.map_to_local(cell)
			var obj_instance = config.object_prefab.instantiate()
			object_container.add_child(obj_instance)
			obj_instance.global_position = world_pos
#endregion
