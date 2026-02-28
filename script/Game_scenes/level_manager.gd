extends Node2D
class_name LevelGenerator

## 关卡生成器 (LevelGenerator)
## 职责：纯粹的“场景建造包工头”。
## 特性：场景加载时，自动从全局大管家 (GameManager) 获取要带入的物品，生成地图块、空气墙边界，重置玩家位置，并响应导演的刷怪指令。

#region 1. 引用配置
@export_group("References")
@export var game_director: GameDirector ## 引用探险导演脚本，用于接收刷怪指令
@export var tile_map: TileMapLayer ## 引用地图图块层
@export var player: CharacterBase ## 引用玩家角色实例
@export var object_container: Node2D ## 存放生成的怪物、物件的容器节点

@export_group("Generation Config")
@export var safe_zone_radius: int = 1 ## 玩家出生点周围的安全区半径 (此范围内不刷怪和物件)

@export_group("Map Config")
@export var tile_source_id: int = 0 ## TileSet 中的图块源 ID
@export var tile_size: Vector2i = Vector2i(32, 32) ## 单个瓦片的像素大小
@export var default_map_width: int = 20 ## 默认地图宽度 (格子数)
@export var default_map_height: int = 20 ## 默认地图高度 (格子数)

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

#region 2. 内部节点与状态
@onready var hud: CanvasLayer = $"../GameHUD" ## 引用 HUD 层 (仅保留武器调整信号连接用)
var boundary_container: Node2D ## 动态创建的空气墙容器
#endregion

#region 3. 生命周期
## [初始化] 准备就绪后，主动向 GameManager 索要 ERS 物品，并开工建图。
func _ready() -> void:
	randomize()

	# 1. 创建空气墙容器
	boundary_container = Node2D.new()
	boundary_container.name = "WorldBoundaries"
	add_child(boundary_container)

	await get_tree().process_frame
	
	# 2. 连接导演的阶段变化信号 (用于分波次刷怪)
	var director = game_director
	if not director:
		director = get_parent().get_node_or_null("GameDirector") as GameDirector
	
	if director:
		if not director.phase_changed.is_connected(_on_phase_changed):
			director.phase_changed.connect(_on_phase_changed)
			print(">>> [LevelGenerator] 成功连接到 GameDirector 信号")
	else:
		push_error(">>> [LevelGenerator] 找不到 GameDirector 节点！刷怪功能将失效。")

	# 3. 兼容旧有的武器 UI 调整逻辑 (如果有的话)
	if player and hud:
		var weapon_node = player.get_node_or_null("WeaponAdmin/WeaponCurrent/Weapon_Gravitation")
		if weapon_node:
			if hud.has_signal("angle_changed"): hud.angle_changed.connect(weapon_node.set_attack_angle)
			if hud.has_signal("radius_changed"): hud.radius_changed.connect(weapon_node.set_attack_radius)

	# 4. [核心架构接入] 从全局大管家获取带入副本的物品，并直接开始生成关卡
	var ers_items_to_spawn = GameManager.pending_ers_objects
	_build_level(ers_items_to_spawn)
#endregion

#region 4. 关卡建造流程
## [核心建造] 根据参数构建整个地图和初始物件
func _build_level(extra_objects: Array[PackedScene] = []) -> void:
	print(">>> [LevelGenerator] 开始构建关卡...")
	
	var map_w = default_map_width
	var map_h = default_map_height
	
	# 1. 清理可能残留的数据 (正常切场景的话这里应该是空的)
	_clear_objects()
	_clear_boundaries()
	
	# 2. 铺设地砖
	_generate_map_tiles(map_w, map_h)
	
	# 3. 建立四周空气墙
	_create_world_boundary(map_w, map_h)
	
	# 4. 获取中心点，重置玩家位置
	var map_rect = tile_map.get_used_rect()
	var center_cell = map_rect.get_center()
	_reset_player(center_cell)
	
	# 5. 生成从 ERS 带来的强化物件 (放在安全区外)
	_spawn_batch_objects(extra_objects, center_cell, map_w, map_h)
	print(">>> [LevelGenerator] 关卡构建完成！")

## [响应导演] 当昼夜系统切换阶段时触发，负责刷当前波次的怪物
func _on_phase_changed(config: DayLoopConfig) -> void:
	print(">>> [LevelGenerator] 响应导演指令，开始生成波次: ", config.phase_name)
	
	var map_rect = tile_map.get_used_rect()
	var center_cell = map_rect.get_center()
	var map_w = int(map_rect.size.x)
	var map_h = int(map_rect.size.y)
	
	# 解析配置里的怪物/物件列表
	var objects_to_spawn: Array[PackedScene] = []
	for spawn_data in config.phase_spawn_list:
		if spawn_data.object_prefab and spawn_data.spawn_count > 0:
			for i in range(spawn_data.spawn_count):
				objects_to_spawn.append(spawn_data.object_prefab)
	
	# 批量生成
	if not objects_to_spawn.is_empty():
		_spawn_batch_objects(objects_to_spawn, center_cell, map_w, map_h)
#endregion

#region 5. 地图铺设算法
## [地砖] 铺设地板，包含边缘检测和中间重复花纹处理
func _generate_map_tiles(width: int, height: int) -> void:
	tile_map.clear()
	for x in range(width):
		for y in range(height):
			var grid_pos = Vector2i(x, y)
			var atlas_coord = atlas_center_fallback
			
			# 判断是否是四周边界
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
				# 中间区域的花纹平铺
				atlas_coord = _get_center_pattern_coord(x, y)
				
			tile_map.set_cell(grid_pos, tile_source_id, atlas_coord)

## [地砖] 计算中心图案的重复偏移量
func _get_center_pattern_coord(grid_x: int, grid_y: int) -> Vector2i:
	var offset_x = max(0, grid_x - 2)
	var offset_y = max(0, grid_y - 2)
	return center_pattern_start + Vector2i(offset_x % center_pattern_size.x, offset_y % center_pattern_size.y)

## [空气墙] 在地图四周动态生成静态碰撞体，防止玩家或怪物跑出地图
func _create_world_boundary(width: int, height: int) -> void:
	var world_size = Vector2(width * tile_size.x, height * tile_size.y)
	var static_body = StaticBody2D.new()
	static_body.collision_layer = 1 << 4 # 分配到特定的物理层
	boundary_container.add_child(static_body)
	var wall_thickness = 100.0
	
	# 构造上下左右四个矩形碰撞框
	var shapes = [
		[Vector2(world_size.x + wall_thickness * 2, wall_thickness), Vector2(world_size.x / 2.0, -wall_thickness / 2.0)], # 上
		[Vector2(world_size.x + wall_thickness * 2, wall_thickness), Vector2(world_size.x / 2.0, world_size.y + wall_thickness / 2.0)], # 下
		[Vector2(wall_thickness, world_size.y + wall_thickness * 2), Vector2(-wall_thickness / 2.0, world_size.y / 2.0)], # 左
		[Vector2(wall_thickness, world_size.y + wall_thickness * 2), Vector2(world_size.x + wall_thickness / 2.0, world_size.y / 2.0)]  # 右
	]
	
	for s in shapes:
		var col = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = s[0]
		col.shape = rect
		col.position = s[1]
		static_body.add_child(col)
#endregion

#region 6. 实体生成逻辑
## [实体生成] 在地图的合法区域内，批量随机生成指定的实体列表
func _spawn_batch_objects(objects: Array[PackedScene], center_cell: Vector2i, map_w: int, map_h: int) -> void:
	if objects.is_empty(): return
	
	var valid_cells = _get_all_valid_spawn_cells(center_cell, map_w, map_h)
	valid_cells.shuffle() # 打乱可选的生成点位置，实现随机化
	
	var current_idx = 0
	for prefab in objects:
		if current_idx >= valid_cells.size(): break # 如果地图满了，就不再生成
		_instantiate_object_at(valid_cells[current_idx], prefab)
		current_idx += 1

## [实体生成] 计算并返回所有可用于生成的格子(剔除边缘墙壁和玩家安全区)
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
		
		# 只有不在边界边缘、不在玩家脚下安全区的格子，才是合法的
		if not is_border and not is_safe_zone:
			valid_cells.append(cell)
			
	return valid_cells

## [实体生成] 在指定的格子位置实例化预制体
func _instantiate_object_at(cell: Vector2i, prefab: PackedScene) -> void:
	var world_pos = tile_map.map_to_local(cell)
	var obj_instance = prefab.instantiate()
	object_container.add_child(obj_instance)
	obj_instance.global_position = world_pos
#endregion

#region 7. 辅助功能
## [辅助] 清空地图上现存的所有容器内的实体
func _clear_objects() -> void:
	for child in object_container.get_children():
		child.queue_free()

## [辅助] 清空上一次生成的空气墙边界
func _clear_boundaries() -> void:
	for child in boundary_container.get_children():
		child.queue_free()

## [辅助] 重置玩家的位置到地图中心
func _reset_player(center_cell: Vector2i) -> void:
	if player:
		var reset_pos = tile_map.map_to_local(center_cell)
		player.global_position = reset_pos
		player.velocity = Vector2.ZERO
#endregion
