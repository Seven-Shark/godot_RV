extends Node2D

#region 引用配置
@export_group("References")
@export var tile_map: TileMapLayer ## 引用地图层
@export var player: CharacterBase ## 引用玩家
@export var object_container: Node2D ## 物件容器
@export var spawnable_objects: Array[PackedScene] ## 基础生成物列表
# 【新增】引用 ERS 管理器 (需要在场景里把 ERS_Manager 节点拖进来)
@export var ers_manager: ERS_Manager

@export_group("Generation Config")
@export var spawn_config_list: Array[SpawnData] ## 基础资源生成配置
@export var safe_zone_radius: int = 5 ## 安全区半径

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
@export_subgroup("Center Pattern Loop")
@export var center_pattern_start: Vector2i = Vector2i(2, 2)
@export var center_pattern_size: Vector2i = Vector2i(8, 8)
@export var atlas_center_fallback: Vector2i = Vector2i(1, 1) 
#endregion

#region 节点引用
@onready var new_day_button: Button = $"../GameHUD/NewDayButton"
@onready var hud: CanvasLayer = $"../GameHUD"
@onready var height_input: SpinBox = $"../GameHUD/NewDayButton/HeightInput"
@onready var width_input: SpinBox = $"../GameHUD/NewDayButton/WidthInput"


#endregion

#region 内部变量
var current_objects: Array[Node] = [] 
#endregion

#region 生命周期
func _ready() -> void:
	randomize()

	# 连接 HUD 和 武器
	await get_tree().process_frame
	if player and hud:
		var weapon_node = player.get_node_or_null("WeaponAdmin/WeaponCurrent/Weapon_Gravitation")
		if weapon_node:
			hud.angle_changed.connect(weapon_node.set_attack_angle)
			hud.radius_changed.connect(weapon_node.set_attack_radius)
#endregion

#region 信号回调
# [新增] ERS 流程结束后的回调
# purchased_objects: 玩家在 ERS 界面购买的物件预制体列表
func _on_ers_finished_start_day(purchased_objects: Array[PackedScene]):
	print(">>> ERS 结束，接收到 %d 个额外物件，开始生成..." % purchased_objects.size())
	start_new_day(purchased_objects)
#endregion

#region 核心功能
# [修改] 支持接收额外物件列表 (默认为空数组)
func start_new_day(extra_objects: Array[PackedScene] = []):
	print(">>> 开启新的一天...")
	
	var map_w = 20
	var map_h = 20
	
	if width_input: map_w = int(width_input.value)
	if height_input: map_h = int(height_input.value)
	
	# 1. 清理旧物件
	_clear_objects()
	
	# 2. 生成地图
	_generate_map_tiles(map_w, map_h)
	
	var map_rect = tile_map.get_used_rect()
	var center_cell = map_rect.get_center()
	
	# 3. 重置玩家
	_reset_player(center_cell)
	
	# 4. 生成物件 (传入 ERS 购买的额外物件)
	_spawn_new_objects(center_cell, extra_objects)

# 地图生成逻辑 (保持不变)
func _generate_map_tiles(width: int, height: int):
	# ... (省略具体实现，保持你原有的逻辑不变即可) ...
	# 为了不让代码太长，这里我简略了，请保留你原来的 _generate_map_tiles 完整代码
	print("正在生成地图，尺寸: ", width, " x ", height)
	tile_map.clear()
	for x in range(width):
		for y in range(height):
			var grid_pos = Vector2i(x, y)
			var atlas_coord = atlas_center_fallback
			if x == 0 or x == width - 1 or y == 0 or y == height - 1:
				if x == 0: 
					if y == 0: atlas_coord = atlas_top_left
					elif y == height - 1: atlas_coord = atlas_bottom_left
					else: atlas_coord = atlas_left_list[(y - 1) % atlas_left_list.size()]
				elif x == width - 1: 
					if y == 0: atlas_coord = atlas_top_right
					elif y == height - 1: atlas_coord = atlas_bottom_right
					else: atlas_coord = atlas_right_list[(y - 1) % atlas_right_list.size()]
				else: 
					if y == 0: atlas_coord = atlas_top_list[(x - 1) % atlas_top_list.size()]
					elif y == height - 1: atlas_coord = atlas_bottom_list[(x - 1) % atlas_bottom_list.size()]
			elif (x == 1 or x == width - 2 or y == 1 or y == height - 2) and width > 4 and height > 4:
				var is_inner_corner = (x==1 and y==1) or (x==width-2 and y==1) or (x==1 and y==height-2) or (x==width-2 and y==height-2)
				var handled = false
				if not is_inner_corner:
					if x == 1 and not atlas_inner_left_list.is_empty():
						atlas_coord = atlas_inner_left_list[(y - 2) % atlas_inner_left_list.size()]; handled = true
					elif x == width - 2 and not atlas_inner_right_list.is_empty():
						atlas_coord = atlas_inner_right_list[(y - 2) % atlas_inner_right_list.size()]; handled = true
					elif y == 1 and not atlas_inner_top_list.is_empty():
						atlas_coord = atlas_inner_top_list[(x - 2) % atlas_inner_top_list.size()]; handled = true
					elif y == height - 2 and not atlas_inner_bottom_list.is_empty():
						atlas_coord = atlas_inner_bottom_list[(x - 2) % atlas_inner_bottom_list.size()]; handled = true
				if not handled: atlas_coord = _get_center_pattern_coord(x, y)
			else:
				atlas_coord = _get_center_pattern_coord(x, y)
			tile_map.set_cell(grid_pos, tile_source_id, atlas_coord)

func _get_center_pattern_coord(grid_x: int, grid_y: int) -> Vector2i:
	var offset_x = max(0, grid_x - 2)
	var offset_y = max(0, grid_y - 2)
	return center_pattern_start + Vector2i(offset_x % center_pattern_size.x, offset_y % center_pattern_size.y)

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

# [内部] 生成物件 (整合了基础配置和 ERS 购买物品)
func _spawn_new_objects(center_cell: Vector2i, extra_objects: Array[PackedScene]):
	# 1. 收集所有有效的生成格子
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
	
	# 打乱格子顺序，确保随机性
	valid_cells.shuffle()
	
	var current_cell_index = 0 # 全局格子索引，确保不重叠
	
	# -------------------------------------------------
	# 阶段 A: 生成基础配置列表 (spawn_config_list)
	# -------------------------------------------------
	if not spawn_config_list.is_empty():
		for config in spawn_config_list:
			if not config.object_prefab or config.spawn_count <= 0: continue
				
			for i in range(config.spawn_count):
				if current_cell_index >= valid_cells.size(): 
					push_warning("格子已满，停止生成基础物件")
					return 
				
				_instantiate_object_at(valid_cells[current_cell_index], config.object_prefab)
				current_cell_index += 1

	# -------------------------------------------------
	# 阶段 B: 生成 ERS 购买的额外物件 (extra_objects)
	# -------------------------------------------------
	if not extra_objects.is_empty():
		for prefab in extra_objects:
			if current_cell_index >= valid_cells.size():
				push_warning("格子已满，停止生成 ERS 购买物件")
				return
			
			_instantiate_object_at(valid_cells[current_cell_index], prefab)
			current_cell_index += 1
			
	print("生成完毕，共使用了 ", current_cell_index, " 个格子")

# [辅助] 在指定格子实例化物件
func _instantiate_object_at(cell: Vector2i, prefab: PackedScene):
	var world_pos = tile_map.map_to_local(cell)
	var obj_instance = prefab.instantiate()
	object_container.add_child(obj_instance)
	obj_instance.global_position = world_pos
#endregion
