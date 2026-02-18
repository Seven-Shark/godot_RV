extends Node2D
class_name LevelManager

#region 1. 引用配置
@export_group("References")
@export var tile_map: TileMapLayer ## 引用地图图块层
@export var player: CharacterBase ## 引用玩家角色实例
@export var object_container: Node2D ## 存放生成物件的容器节点
@export var ers_manager: ERS_Manager ## 引用环境重构 (ERS) 管理器

@export_group("Generation Config")
@export var spawn_config_list: Array[SpawnData] ## [已弃用] 基础资源生成配置列表 (现改用 DayPhaseConfig 控制)
@export var safe_zone_radius: int = 1 ## 玩家出生点周围的安全区半径（单位：格）

@export_group("Map Config")
@export var tile_source_id: int = 0 ## TileSet 中的图块源 ID
@export var tile_size: Vector2i = Vector2i(32, 32) ## 单个瓦片的像素大小
@export var default_map_width: int = 20 ## 默认地图宽度
@export var default_map_height: int = 20 ## 默认地图高度

@export_subgroup("Outer Layer (Edges & Corners)")
@export var atlas_top_left: Vector2i = Vector2i(0, 0) ## 左上角图块坐标
@export var atlas_top_right: Vector2i = Vector2i(2, 0) ## 右上角图块坐标
@export var atlas_bottom_left: Vector2i = Vector2i(0, 2) ## 左下角图块坐标
@export var atlas_bottom_right: Vector2i = Vector2i(2, 2) ## 右下角图块坐标
@export var atlas_top_list: Array[Vector2i] = [Vector2i(1, 0)] ## 上边缘图块列表
@export var atlas_bottom_list: Array[Vector2i] = [Vector2i(1, 2)] ## 下边缘图块列表
@export var atlas_left_list: Array[Vector2i] = [Vector2i(0, 1)] ## 左边缘图块列表
@export var atlas_right_list: Array[Vector2i] = [Vector2i(2, 1)] ## 右边缘图块列表

@export_subgroup("Inner Layer (Row 2 / Col 2)")
@export var atlas_inner_top_list: Array[Vector2i] = [] ## 内圈上边缘
@export var atlas_inner_bottom_list: Array[Vector2i] = [] ## 内圈下边缘
@export var atlas_inner_left_list: Array[Vector2i] = [] ## 内圈左边缘
@export var atlas_inner_right_list: Array[Vector2i] = [] ## 内圈右边缘

@export_subgroup("Center Pattern Loop")
@export var center_pattern_start: Vector2i = Vector2i(2, 2) ## 中间图案起始坐标
@export var center_pattern_size: Vector2i = Vector2i(8, 8) ## 中间图案循环尺寸
@export var atlas_center_fallback: Vector2i = Vector2i(1, 1) ## 兜底填充图块
#endregion

#region 2. 节点引用
@onready var new_day_button: Button = $"../GameHUD/NewDayButton" ## 开启新一天的按钮
@onready var hud: CanvasLayer = $"../GameHUD" ## 游戏 HUD 界面
@onready var height_input: SpinBox = $"../GameHUD/NewDayButton/HeightInput" ## 高度输入框
@onready var width_input: SpinBox = $"../GameHUD/NewDayButton/WidthInput" ## 宽度输入框

var boundary_container: Node2D ## 空气墙容器
var current_objects: Array[Node] = [] ## 当前生成的物件列表
#endregion

#region 3. 生命周期
## 初始化场景，创建边界容器并连接 UI 信号
func _ready() -> void:
	randomize()

	boundary_container = Node2D.new()
	boundary_container.name = "WorldBoundaries"
	add_child(boundary_container)

	await get_tree().process_frame
	if player and hud:
		var weapon_node = player.get_node_or_null("WeaponAdmin/WeaponCurrent/Weapon_Gravitation")
		if weapon_node:
			hud.angle_changed.connect(weapon_node.set_attack_angle)
			hud.radius_changed.connect(weapon_node.set_attack_radius)
			
	# 连接 Director 的阶段信号
	var director = get_parent() as GameDirector
	if director:
		if not director.phase_changed.is_connected(_on_phase_changed):
			director.phase_changed.connect(_on_phase_changed)
#endregion

#region 4. 核心逻辑入口
## [信号回调] ERS 流程结束，接收购买的物件并启动生成 (由 Director 调用)
func _on_ers_finished_start_day(purchased_objects: Array[PackedScene]) -> void:
	start_new_day(purchased_objects)

## 执行完整的清理、生成地图、放置商店物件流程 (注意：不生成怪物)
func start_new_day(extra_objects: Array[PackedScene] = []) -> void:
	print(">>> [Manager] 初始化地图环境...")
	
	var map_w = default_map_width
	var map_h = default_map_height
	
	if width_input and width_input.value > 5: 
		map_w = int(width_input.value)
	if height_input and height_input.value > 5: 
		map_h = int(height_input.value)
	
	# 1. 清理旧环境
	_clear_objects()
	_clear_boundaries()
	
	# 2. 生成新地形与边界
	_generate_map_tiles(map_w, map_h)
	_create_world_boundary(map_w, map_h)
	
	# 3. 重置玩家位置
	var map_rect = tile_map.get_used_rect()
	var center_cell = map_rect.get_center()
	_reset_player(center_cell)
	
	# 4. 生成商店购买的额外物品 (必须在第一阶段前生成)
	_spawn_batch_objects(extra_objects, center_cell, map_w, map_h)
	
	print(">>> 地图初始化完毕，等待阶段指令...")

## [新增] 响应阶段变化，生成对应阶段的物件
func _on_phase_changed(config: DayLoopConfig) -> void:
	print(">>> [Manager] 收到阶段指令: ", config.phase_name, " | 生成配置数: ", config.phase_spawn_list.size())
	
	var map_rect = tile_map.get_used_rect()
	var center_cell = map_rect.get_center()
	var map_w = int(map_rect.size.x)
	var map_h = int(map_rect.size.y)
	
	# 解析配置中的生成列表
	var objects_to_spawn: Array[PackedScene] = []
	for spawn_data in config.phase_spawn_list:
		if spawn_data.object_prefab and spawn_data.spawn_count > 0:
			for i in range(spawn_data.spawn_count):
				objects_to_spawn.append(spawn_data.object_prefab)
	
	# 执行批量生成 (增量生成，不清除旧的)
	if not objects_to_spawn.is_empty():
		_spawn_batch_objects(objects_to_spawn, center_cell, map_w, map_h)
#endregion

#region 5. 地图生成
## 按照分层规则铺设地图图块
func _generate_map_tiles(width: int, height: int) -> void:
	tile_map.clear()
	for x in range(width):
		for y in range(height):
			var grid_pos = Vector2i(x, y) ## 格子坐标
			var atlas_coord = atlas_center_fallback ## 默认图块
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

## 计算中心填充区域的 Atlas 坐标
func _get_center_pattern_coord(grid_x: int, grid_y: int) -> Vector2i:
	var offset_x = max(0, grid_x - 2)
	var offset_y = max(0, grid_y - 2)
	return center_pattern_start + Vector2i(offset_x % center_pattern_size.x, offset_y % center_pattern_size.y)
#endregion

#region 6. 物件生成 (通用批量处理)
## 批量生成一组物件到随机合法位置
func _spawn_batch_objects(objects: Array[PackedScene], center_cell: Vector2i, map_w: int, map_h: int) -> void:
	if objects.is_empty(): return
	
	# 重新获取当前所有合法空位 (因为地图上可能已有物体)
	var valid_cells = _get_all_valid_spawn_cells(center_cell, map_w, map_h)
	valid_cells.shuffle()
	
	var current_idx = 0
	for prefab in objects:
		if current_idx >= valid_cells.size(): 
			print(">>> [Manager] 地图空位不足，停止生成")
			break
			
		_instantiate_object_at(valid_cells[current_idx], prefab)
		current_idx += 1

## 获取当前地图上所有合法的生成点 (排除边界和安全区)
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
		var is_border = (cell.x == 0 or cell.x == map_w - 1 or cell.y == 0 or cell.y == map_h - 1)
		var is_safe_zone = safe_zone_rect.has_point(cell)
		
		# 可扩展：检测该格子是否已被占用 (如果需要更精细的控制)
		
		if not is_border and not is_safe_zone:
			valid_cells.append(cell)
			
	return valid_cells

## 将物件实例化并设置到指定像素位置 (带自动导航挖洞功能)
func _instantiate_object_at(cell: Vector2i, prefab: PackedScene) -> void:
	var world_pos = tile_map.map_to_local(cell) ## 世界坐标
	var obj_instance = prefab.instantiate() ## 实例
	object_container.add_child(obj_instance)
	obj_instance.global_position = world_pos
	
	# [可选] 如果你想在生成障碍物时切断导航，可以在这里调用 tile_map.set_cell 替换地板
	# tile_map.set_cell(cell, tile_source_id, atlas_obstacle_floor)
#endregion

#region 7. 清理与物理边界
## 清除地图上的所有物件引用
func _clear_objects() -> void:
	for child in object_container.get_children():
		child.queue_free()
	current_objects.clear()

## 清除地图空气墙碰撞体
func _clear_boundaries() -> void:
	for child in boundary_container.get_children():
		child.queue_free()

## 将玩家瞬移回中心并清除动量
func _reset_player(center_cell: Vector2i) -> void:
	if player:
		var reset_pos = tile_map.map_to_local(center_cell)
		player.global_position = reset_pos
		player.velocity = Vector2.ZERO

## 动态创建围绕地图边缘的物理空气墙
func _create_world_boundary(width: int, height: int) -> void:
	var world_size = Vector2(width * tile_size.x, height * tile_size.y) ## 地图像素总尺寸
	var static_body = StaticBody2D.new() ## 边界物体
	static_body.name = "BoundaryColliders"
	static_body.collision_layer = 1 << 4 
	static_body.collision_mask = 0 
	boundary_container.add_child(static_body)
	var wall_thickness = 100.0 ## 墙体厚度
	
	var top_shape = CollisionShape2D.new()
	var top_rect = RectangleShape2D.new()
	top_rect.size = Vector2(world_size.x + wall_thickness * 2, wall_thickness)
	top_shape.shape = top_rect
	top_shape.position = Vector2(world_size.x / 2.0, -wall_thickness / 2.0)
	static_body.add_child(top_shape)
	
	var bottom_shape = CollisionShape2D.new()
	var bottom_rect = RectangleShape2D.new()
	bottom_rect.size = Vector2(world_size.x + wall_thickness * 2, wall_thickness)
	bottom_shape.shape = bottom_rect
	bottom_shape.position = Vector2(world_size.x / 2.0, world_size.y + wall_thickness / 2.0)
	static_body.add_child(bottom_shape)
	
	var left_shape = CollisionShape2D.new()
	var left_rect = RectangleShape2D.new()
	left_rect.size = Vector2(wall_thickness, world_size.y + wall_thickness * 2)
	left_shape.shape = left_rect
	left_shape.position = Vector2(-wall_thickness / 2.0, world_size.y / 2.0)
	static_body.add_child(left_shape)
	
	var right_shape = CollisionShape2D.new()
	var right_rect = RectangleShape2D.new()
	right_rect.size = Vector2(wall_thickness, world_size.y + wall_thickness * 2)
	right_shape.shape = right_rect
	right_shape.position = Vector2(world_size.x + wall_thickness / 2.0, world_size.y / 2.0)
	static_body.add_child(right_shape)
#endregion
