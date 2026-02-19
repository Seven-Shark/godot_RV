extends Node2D
class_name LevelManager

#region 1. 引用配置
@export_group("References")
@export var game_director: GameDirector ## [新增] 直接引用导演脚本，最稳妥
@export var tile_map: TileMapLayer ## 引用地图图块层
@export var player: CharacterBase ## 引用玩家角色实例
@export var object_container: Node2D ## 存放生成物件的容器节点
@export var ers_manager: ERS_Manager ## 引用环境重构 (ERS) 管理器

@export_group("Generation Config")
@export var safe_zone_radius: int = 1 ## 玩家出生点周围的安全区半径
@export var spawn_config_list: Array[SpawnData] ## [已弃用]

@export_group("Map Config")
@export var tile_source_id: int = 0 ## TileSet 中的图块源 ID
@export var tile_size: Vector2i = Vector2i(32, 32) ## 单个瓦片的像素大小
@export var default_map_width: int = 20 ## 默认地图宽度
@export var default_map_height: int = 20 ## 默认地图高度

@export_subgroup("Outer Layer (Edges & Corners)")
@export var atlas_top_left: Vector2i = Vector2i(0, 0)
@export var atlas_top_right: Vector2i = Vector2i(2, 0)
@export var atlas_bottom_left: Vector2i = Vector2i(0, 2)
@export var atlas_bottom_right: Vector2i = Vector2i(2, 2)
@export var atlas_top_list: Array[Vector2i] = [Vector2i(1, 0)]
@export var atlas_bottom_list: Array[Vector2i] = [Vector2i(1, 2)]
@export var atlas_left_list: Array[Vector2i] = [Vector2i(0, 1)]
@export var atlas_right_list: Array[Vector2i] = [Vector2i(2, 1)]

@export_subgroup("Center Pattern Loop")
@export var center_pattern_start: Vector2i = Vector2i(2, 2)
@export var center_pattern_size: Vector2i = Vector2i(8, 8)
@export var atlas_center_fallback: Vector2i = Vector2i(1, 1)
#endregion

#region 2. 节点引用
@onready var new_day_button: Button = $"../GameHUD/NewDayButton"
@onready var hud: CanvasLayer = $"../GameHUD"
@onready var height_input: SpinBox = $"../GameHUD/NewDayButton/HeightInput"
@onready var width_input: SpinBox = $"../GameHUD/NewDayButton/WidthInput"

var boundary_container: Node2D 
#endregion

#region 3. 生命周期
func _ready() -> void:
	randomize()

	boundary_container = Node2D.new()
	boundary_container.name = "WorldBoundaries"
	add_child(boundary_container)

	await get_tree().process_frame
	
	# --- [核心修复] 修正平级节点的信号连接 ---
	# 如果你在 Inspector 里拖了 GameDirector 进来，就用它；没拖就自动找兄弟节点
	var director = game_director
	if not director:
		director = get_parent().get_node_or_null("GameDirector") as GameDirector
	
	if director:
		if not director.phase_changed.is_connected(_on_phase_changed):
			director.phase_changed.connect(_on_phase_changed)
			print(">>> [LevelManager] 成功连接到平级 GameDirector 信号")
	else:
		push_error(">>> [LevelManager] 找不到 GameDirector 节点！")
	# ---------------------------------------

	if player and hud:
		var weapon_node = player.get_node_or_null("WeaponAdmin/WeaponCurrent/Weapon_Gravitation")
		if weapon_node:
			hud.angle_changed.connect(weapon_node.set_attack_angle)
			hud.radius_changed.connect(weapon_node.set_attack_radius)
#endregion

#region 4. 核心逻辑入口
func _on_ers_finished_start_day(purchased_objects: Array[PackedScene]) -> void:
	start_new_day(purchased_objects)

func start_new_day(extra_objects: Array[PackedScene] = []) -> void:
	print(">>> [Manager] 开启新的一天，重置环境...")
	
	var map_w = default_map_width
	var map_h = default_map_height
	
	if width_input and width_input.value > 5: map_w = int(width_input.value)
	if height_input and height_input.value > 5: map_h = int(height_input.value)
	
	_clear_objects()
	_clear_boundaries()
	_generate_map_tiles(map_w, map_h)
	_create_world_boundary(map_w, map_h)
	
	var map_rect = tile_map.get_used_rect()
	var center_cell = map_rect.get_center()
	
	_reset_player(center_cell)
	_spawn_batch_objects(extra_objects, center_cell, map_w, map_h)

## 响应昼夜阶段变化信号
func _on_phase_changed(config: DayLoopConfig) -> void:
	print(">>> [Manager] 收到阶段指令: ", config.phase_name)
	
	var map_rect = tile_map.get_used_rect()
	var center_cell = map_rect.get_center()
	var map_w = int(map_rect.size.x)
	var map_h = int(map_rect.size.y)
	
	var objects_to_spawn: Array[PackedScene] = []
	for spawn_data in config.phase_spawn_list:
		if spawn_data.object_prefab and spawn_data.spawn_count > 0:
			for i in range(spawn_data.spawn_count):
				objects_to_spawn.append(spawn_data.object_prefab)
	
	if not objects_to_spawn.is_empty():
		_spawn_batch_objects(objects_to_spawn, center_cell, map_w, map_h)
#endregion

#region 5. 地图生成 (逻辑保持不变)
func _generate_map_tiles(width: int, height: int) -> void:
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
			else:
				atlas_coord = _get_center_pattern_coord(x, y)
			tile_map.set_cell(grid_pos, tile_source_id, atlas_coord)

func _get_center_pattern_coord(grid_x: int, grid_y: int) -> Vector2i:
	var offset_x = max(0, grid_x - 2)
	var offset_y = max(0, grid_y - 2)
	return center_pattern_start + Vector2i(offset_x % center_pattern_size.x, offset_y % center_pattern_size.y)
#endregion

#region 6. 物件生成逻辑
func _spawn_batch_objects(objects: Array[PackedScene], center_cell: Vector2i, map_w: int, map_h: int) -> void:
	if objects.is_empty(): return
	
	var valid_cells = _get_all_valid_spawn_cells(center_cell, map_w, map_h)
	valid_cells.shuffle()
	
	var current_idx = 0
	for prefab in objects:
		if current_idx >= valid_cells.size(): break
		_instantiate_object_at(valid_cells[current_idx], prefab)
		current_idx += 1

func _get_all_valid_spawn_cells(center_cell: Vector2i, map_w: int, map_h: int) -> Array[Vector2i]:
	var valid_cells: Array[Vector2i] = []
	var used_cells = tile_map.get_used_cells()
	
	var safe_zone_rect = Rect2i(
		center_cell.x - safe_zone_radius, 
		center_cell.y - safe_zone_radius, 
		safe_zone_radius * 2 + 1, 
		safe_zone_radius * 2 + 1
	)
	
	for cell in used_cells:
		# --- [修正点] 使用参数 map_w/map_h 而不是错误的全局变量名 ---
		var is_border = (cell.x == 0 or cell.x == map_w - 1 or cell.y == 0 or cell.y == map_h - 1)
		var is_safe_zone = safe_zone_rect.has_point(cell)
		
		if not is_border and not is_safe_zone:
			valid_cells.append(cell)
			
	return valid_cells

func _instantiate_object_at(cell: Vector2i, prefab: PackedScene) -> void:
	var world_pos = tile_map.map_to_local(cell)
	var obj_instance = prefab.instantiate()
	object_container.add_child(obj_instance)
	obj_instance.global_position = world_pos
#endregion

#region 7. 清理与重置 (逻辑保持不变)
func _clear_objects() -> void:
	for child in object_container.get_children():
		child.queue_free()

func _clear_boundaries() -> void:
	for child in boundary_container.get_children():
		child.queue_free()

func _reset_player(center_cell: Vector2i) -> void:
	if player:
		var reset_pos = tile_map.map_to_local(center_cell)
		player.global_position = reset_pos
		player.velocity = Vector2.ZERO

func _create_world_boundary(width: int, height: int) -> void:
	var world_size = Vector2(width * tile_size.x, height * tile_size.y)
	var static_body = StaticBody2D.new()
	static_body.collision_layer = 1 << 4 
	boundary_container.add_child(static_body)
	var wall_thickness = 100.0
	
	var shapes = [
		[Vector2(world_size.x + wall_thickness * 2, wall_thickness), Vector2(world_size.x / 2.0, -wall_thickness / 2.0)],
		[Vector2(world_size.x + wall_thickness * 2, wall_thickness), Vector2(world_size.x / 2.0, world_size.y + wall_thickness / 2.0)],
		[Vector2(wall_thickness, world_size.y + wall_thickness * 2), Vector2(-wall_thickness / 2.0, world_size.y / 2.0)],
		[Vector2(wall_thickness, world_size.y + wall_thickness * 2), Vector2(world_size.x + wall_thickness / 2.0, world_size.y / 2.0)]
	]
	
	for s in shapes:
		var col = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = s[0]
		col.shape = rect
		col.position = s[1]
		static_body.add_child(col)
#endregion
