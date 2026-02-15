extends Node2D
class_name GameManager

#region 引用配置
@export_group("References")
@export var tile_map: TileMapLayer ## 引用地图层
@export var player: CharacterBase ## 引用玩家
@export var object_container: Node2D ## 物件容器
@export var ers_manager: ERS_Manager ## 引用 ERS 管理器 (需要在场景里把 ERS_Manager 节点拖进来)

@export_group("Generation Config")
@export var spawn_config_list: Array[SpawnData] ## 基础资源生成配置
@export var safe_zone_radius: int = 1 ## 安全区半径

@export_group("Map Config")
@export var tile_source_id: int = 0 ## 图块源 ID
@export var tile_size: Vector2i = Vector2i(32, 32) ## [关键] 瓦片像素大小，用于计算空气墙位置
@export var default_map_width: int = 20 ## [新增] 默认地图宽度
@export var default_map_height: int = 20 ## [新增] 默认地图高度

# --- 第一层：最外圈配置 (Outer Layer) ---
@export_subgroup("Outer Layer (Edges & Corners)")
@export var atlas_top_left: Vector2i = Vector2i(0, 0) ## 左上角图块坐标
@export var atlas_top_right: Vector2i = Vector2i(2, 0) ## 右上角图块坐标
@export var atlas_bottom_left: Vector2i = Vector2i(0, 2) ## 左下角图块坐标
@export var atlas_bottom_right: Vector2i = Vector2i(2, 2) ## 右下角图块坐标

@export var atlas_top_list: Array[Vector2i] = [Vector2i(1, 0)] ## 上边缘图块列表
@export var atlas_bottom_list: Array[Vector2i] = [Vector2i(1, 2)] ## 下边缘图块列表
@export var atlas_left_list: Array[Vector2i] = [Vector2i(0, 1)] ## 左边缘图块列表
@export var atlas_right_list: Array[Vector2i] = [Vector2i(2, 1)] ## 右边缘图块列表

# --- 第二层：内圈配置 (Inner Layer) ---
@export_subgroup("Inner Layer (Row 2 / Col 2)")
@export var atlas_inner_top_list: Array[Vector2i] = [] ## 内圈上边缘
@export var atlas_inner_bottom_list: Array[Vector2i] = [] ## 内圈下边缘
@export var atlas_inner_left_list: Array[Vector2i] = [] ## 内圈左边缘
@export var atlas_inner_right_list: Array[Vector2i] = [] ## 内圈右边缘

# --- 第三层：中间填充图案配置 (Center Pattern) ---
@export_subgroup("Center Pattern Loop")
@export var center_pattern_start: Vector2i = Vector2i(2, 2) ## 中间图案起始坐标
@export var center_pattern_size: Vector2i = Vector2i(8, 8) ## 中间图案循环尺寸
@export var atlas_center_fallback: Vector2i = Vector2i(1, 1) ## 兜底填充图块
#endregion

#region 节点引用
@onready var new_day_button: Button = $"../GameHUD/NewDayButton"
@onready var hud: CanvasLayer = $"../GameHUD"
@onready var height_input: SpinBox = $"../GameHUD/NewDayButton/HeightInput"
@onready var width_input: SpinBox = $"../GameHUD/NewDayButton/WidthInput"

# [新增] 空气墙容器
var boundary_container: Node2D
#endregion

#region 内部变量
var current_objects: Array[Node] = [] ## 当前生成的物件列表
#endregion

#region 生命周期
func _ready() -> void:
	randomize()

	# 创建空气墙容器
	boundary_container = Node2D.new()
	boundary_container.name = "WorldBoundaries"
	add_child(boundary_container)

	# 连接 HUD 和 武器
	await get_tree().process_frame
	if player and hud:
		var weapon_node = player.get_node_or_null("WeaponAdmin/WeaponCurrent/Weapon_Gravitation")
		if weapon_node:
			hud.angle_changed.connect(weapon_node.set_attack_angle)
			hud.radius_changed.connect(weapon_node.set_attack_radius)
#endregion

#region 信号回调
## [回调] ERS 流程结束后的回调，开始新的一天
func _on_ers_finished_start_day(purchased_objects: Array[PackedScene]):
	print(">>> ERS 结束，接收到 %d 个额外物件，开始生成..." % purchased_objects.size())
	start_new_day(purchased_objects)
#endregion

#region 核心功能
## 开启新的一天，重新生成地图和物件
func start_new_day(extra_objects: Array[PackedScene] = []):
	print(">>> 开启新的一天...")
	
	var map_w = default_map_width
	var map_h = default_map_height
	
# 2. 如果 UI 输入框存在且有值，则覆盖默认值 (可选逻辑，方便调试)
	if width_input and width_input.value > 5: 
		map_w = int(width_input.value)
	if height_input and height_input.value > 5: 
		map_h = int(height_input.value)
	
	# 1. 清理旧物件 & 旧空气墙
	_clear_objects()
	_clear_boundaries()
	
	# 2. 生成地图
	_generate_map_tiles(map_w, map_h)
	
	# 3. [核心] 生成 Layer 5 的空气墙
	_create_world_boundary(map_w, map_h)
	
	var map_rect = tile_map.get_used_rect()
	var center_cell = map_rect.get_center()
	
	# 4. 重置玩家
	_reset_player(center_cell)
	
	# 5. 生成物件 (传入地图尺寸，用于排除边界)
	_spawn_new_objects(center_cell, extra_objects, map_w, map_h)

## 生成地图图块逻辑
func _generate_map_tiles(width: int, height: int):
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

## 获取中间重复图案的坐标
func _get_center_pattern_coord(grid_x: int, grid_y: int) -> Vector2i:
	var offset_x = max(0, grid_x - 2)
	var offset_y = max(0, grid_y - 2)
	return center_pattern_start + Vector2i(offset_x % center_pattern_size.x, offset_y % center_pattern_size.y)

## [内部] 清理当前场景中的物件
func _clear_objects():
	for child in object_container.get_children():
		child.queue_free()
	current_objects.clear()

## [内部] 清理当前的空气墙
func _clear_boundaries():
	for child in boundary_container.get_children():
		child.queue_free()

## [内部] 将玩家重置到地图中心
func _reset_player(center_cell: Vector2i):
	if player:
		var reset_pos = tile_map.map_to_local(center_cell)
		player.global_position = reset_pos
		player.velocity = Vector2.ZERO

## [内部] 生成物件 (整合了基础配置和 ERS 购买物品，并排除边界)
func _spawn_new_objects(center_cell: Vector2i, extra_objects: Array[PackedScene], map_width: int, map_height: int):
	# 1. 收集所有有效的生成格子
	var valid_cells: Array[Vector2i] = []
	var used_cells = tile_map.get_used_cells()
	
	# 定义安全区 (玩家出生点周围)
	var safe_zone_rect = Rect2i(
		center_cell.x - safe_zone_radius, 
		center_cell.y - safe_zone_radius, 
		safe_zone_radius * 2 + 1, 
		safe_zone_radius * 2 + 1
	)
	
	for cell in used_cells:
		# [关键逻辑] 排除最外圈的格子 (空气墙位置)
		# 如果 x=0 或 x=max 或 y=0 或 y=max，则跳过
		var is_border = (cell.x == 0 or cell.x == map_width - 1 or cell.y == 0 or cell.y == map_height - 1)
		
		# [关键逻辑] 排除安全区
		var is_safe_zone = safe_zone_rect.has_point(cell)
		
		if not is_border and not is_safe_zone:
			valid_cells.append(cell)
	
	# 打乱格子顺序
	valid_cells.shuffle()
	
	var current_cell_index = 0
	
	# A. 生成基础配置
	if not spawn_config_list.is_empty():
		for config in spawn_config_list:
			if not config.object_prefab or config.spawn_count <= 0: continue
			for i in range(config.spawn_count):
				if current_cell_index >= valid_cells.size(): break
				_instantiate_object_at(valid_cells[current_cell_index], config.object_prefab)
				current_cell_index += 1

	# B. 生成 ERS 额外物件
	if not extra_objects.is_empty():
		for prefab in extra_objects:
			if current_cell_index >= valid_cells.size(): break
			_instantiate_object_at(valid_cells[current_cell_index], prefab)
			current_cell_index += 1
			
	print("生成完毕，共使用了 ", current_cell_index, " 个格子")

## [辅助] 在指定格子实例化物件
func _instantiate_object_at(cell: Vector2i, prefab: PackedScene):
	var world_pos = tile_map.map_to_local(cell)
	var obj_instance = prefab.instantiate()
	object_container.add_child(obj_instance)
	obj_instance.global_position = world_pos

## [新增] 创建世界边界 (空气墙)，指定为 Layer 5
func _create_world_boundary(width: int, height: int):
	# 计算地图的物理尺寸 (像素)
	var world_size = Vector2(width * tile_size.x, height * tile_size.y)
	
	# 创建 StaticBody2D
	var static_body = StaticBody2D.new()
	static_body.name = "BoundaryColliders"
	
	# [修改] 设置空气墙的物理层级为 Layer 5 (二进制 10000 = 十进制 16)
	# 确保 Player 和 Enemy 的 Mask 勾选了 Layer 5
	static_body.collision_layer = 1 << 4 
	static_body.collision_mask = 0 # 墙壁不需要主动去撞别人
	
	boundary_container.add_child(static_body)
	
	# 定义 4 个墙壁的形状 (上、下、左、右)
	# 墙壁厚度设为 100，防止高速物体穿透
	var wall_thickness = 100.0
	
	# 1. 上墙 (Top)
	var top_shape = CollisionShape2D.new()
	var top_rect = RectangleShape2D.new()
	top_rect.size = Vector2(world_size.x + wall_thickness * 2, wall_thickness)
	top_shape.shape = top_rect
	top_shape.position = Vector2(world_size.x / 2.0, -wall_thickness / 2.0)
	static_body.add_child(top_shape)
	
	# 2. 下墙 (Bottom)
	var bottom_shape = CollisionShape2D.new()
	var bottom_rect = RectangleShape2D.new()
	bottom_rect.size = Vector2(world_size.x + wall_thickness * 2, wall_thickness)
	bottom_shape.shape = bottom_rect
	bottom_shape.position = Vector2(world_size.x / 2.0, world_size.y + wall_thickness / 2.0)
	static_body.add_child(bottom_shape)
	
	# 3. 左墙 (Left)
	var left_shape = CollisionShape2D.new()
	var left_rect = RectangleShape2D.new()
	left_rect.size = Vector2(wall_thickness, world_size.y + wall_thickness * 2)
	left_shape.shape = left_rect
	left_shape.position = Vector2(-wall_thickness / 2.0, world_size.y / 2.0)
	static_body.add_child(left_shape)
	
	# 4. 右墙 (Right)
	var right_shape = CollisionShape2D.new()
	var right_rect = RectangleShape2D.new()
	right_rect.size = Vector2(wall_thickness, world_size.y + wall_thickness * 2)
	right_shape.shape = right_rect
	right_shape.position = Vector2(world_size.x + wall_thickness / 2.0, world_size.y / 2.0)
	static_body.add_child(right_shape)
	
	print("空气墙已生成 (Layer 5)，地图范围: ", world_size)
#endregion
