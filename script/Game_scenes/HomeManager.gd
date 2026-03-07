extends Node2D
class_name HomeManager

## 家园管家 (HomeManager)
## 职责：管理家园初始化、自动生成地块与空气墙、将传送门定位于右下角、玩家出生于中心。

#region 1. 引用配置
@export_group("References")
@export var player: CharacterBase ## 玩家节点实例
@export var spawn_point: Marker2D ## 出生点标记节点
@export var home_portal: Area2D ## 家园传送门节点
@export var nav_region: NavigationRegion2D ## 导航网格区域
@export var tile_map: TileMapLayer ## 地砖图层

@export_group("Home Map Config")
@export var map_width: int = 15 ## 地图宽度
@export var map_height: int = 15 ## 地图高度
@export var tile_source_id: int = 0 ## TileSet源ID
@export var tile_size: Vector2i = Vector2i(32, 32) ## 单个瓦片尺寸

@export_subgroup("Tile Atlas Config")
@export var atlas_top_left: Vector2i = Vector2i(0, 0)
@export var atlas_top_right: Vector2i = Vector2i(2, 0)
@export var atlas_bottom_left: Vector2i = Vector2i(0, 2)
@export var atlas_bottom_right: Vector2i = Vector2i(2, 2)
@export var atlas_top_list: Array[Vector2i] = [Vector2i(1, 0)]
@export var atlas_bottom_list: Array[Vector2i] = [Vector2i(1, 2)]
@export var atlas_left_list: Array[Vector2i] = [Vector2i(0, 1)]
@export var atlas_right_list: Array[Vector2i] = [Vector2i(2, 1)]
@export var atlas_center_fallback: Vector2i = Vector2i(1, 1)
@export var center_pattern_start: Vector2i = Vector2i(2, 2)
@export var center_pattern_size: Vector2i = Vector2i(8, 8)
#endregion

#region 2. 内部变量
var boundary_container: Node2D ## 空气墙容器
#endregion

#region 3. 生命周期
## [初始化] 执行家园构建流水线
func _ready() -> void:
	# 0. 准备容器
	boundary_container = Node2D.new()
	boundary_container.name = "WorldBoundaries"
	add_child(boundary_container)
	
	# 1. 生成地砖
	_generate_home_tiles()
	
	# 2. 生成空气墙 (基于地图实际占用范围)
	_create_world_boundary()
	
	# 3. 布局关键设施 (传送门右下，玩家居中)
	_layout_home_elements()
	
	# 4. 重置玩家位置
	if player and spawn_point:
		player.global_position = spawn_point.global_position
		player.velocity = Vector2.ZERO
		player.reset_status()
	
	# 5. 烘焙导航
	call_deferred("_bake_navigation_mesh")

#endregion

#region 4. 地图与物理构建
## [地砖生成] 按照宽高铺设带边界的地板
func _generate_home_tiles() -> void:
	if not tile_map: return
	tile_map.clear()
	
	for x in range(map_width):
		for y in range(map_height):
			var grid_pos = Vector2i(x, y)
			var atlas_coord = atlas_center_fallback
			
			if x == 0 or x == map_width - 1 or y == 0 or y == map_height - 1:
				if x == 0: 
					if y == 0: atlas_coord = atlas_top_left
					elif y == map_height - 1: atlas_coord = atlas_bottom_left
					else: atlas_coord = atlas_left_list[(y - 1) % atlas_left_list.size()]
				elif x == map_width - 1: 
					if y == 0: atlas_coord = atlas_top_right
					elif y == map_height - 1: atlas_coord = atlas_bottom_right
					else: atlas_coord = atlas_right_list[(y - 1) % atlas_right_list.size()]
				else: 
					if y == 0: atlas_coord = atlas_top_list[(x - 1) % atlas_top_list.size()]
					elif y == map_height - 1: atlas_coord = atlas_bottom_list[(x - 1) % atlas_bottom_list.size()]
			else:
				var offset_x = max(0, x - 2)
				var offset_y = max(0, y - 2)
				atlas_coord = center_pattern_start + Vector2i(offset_x % center_pattern_size.x, offset_y % center_pattern_size.y)
				
			tile_map.set_cell(grid_pos, tile_source_id, atlas_coord)

## [空气墙生成] 自动识别地图边缘并包裹碰撞体
func _create_world_boundary() -> void:
	if not tile_map: return
	var used_rect = tile_map.get_used_rect()
	if not used_rect.has_area(): return
	
	var half_tile = Vector2(tile_size) / 2.0
	var top_left_px = tile_map.map_to_local(used_rect.position) - half_tile
	var bottom_right_px = tile_map.map_to_local(used_rect.end - Vector2i(1, 1)) + half_tile
	
	var map_w_px = bottom_right_px.x - top_left_px.x
	var map_h_px = bottom_right_px.y - top_left_px.y
	var map_center = (top_left_px + bottom_right_px) / 2.0
	
	var static_body = StaticBody2D.new()
	static_body.collision_layer = 1 << 4 
	boundary_container.add_child(static_body)
	var wall_thick = 100.0
	
	var shapes = [
		{ "size": Vector2(map_w_px + wall_thick * 2, wall_thick), "pos": Vector2(map_center.x, top_left_px.y - wall_thick / 2.0) },
		{ "size": Vector2(map_w_px + wall_thick * 2, wall_thick), "pos": Vector2(map_center.x, bottom_right_px.y + wall_thick / 2.0) },
		{ "size": Vector2(wall_thick, map_h_px + wall_thick * 2), "pos": Vector2(top_left_px.x - wall_thick / 2.0, map_center.y) },
		{ "size": Vector2(wall_thick, map_h_px + wall_thick * 2), "pos": Vector2(bottom_right_px.x + wall_thick / 2.0, map_center.y) }
	]
	
	for s in shapes:
		var col = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = s["size"]
		col.shape = rect
		col.position = s["pos"]
		static_body.add_child(col)
#endregion

#region 5. 元素布局逻辑
## [布局计算] 实现传送门在右下角，玩家在中心
func _layout_home_elements() -> void:
	if not tile_map: return
	var used_rect = tile_map.get_used_rect()
	if not used_rect.has_area(): return

	# 计算世界像素边界
	var half_tile = Vector2(tile_size) / 2.0
	var top_left_px = tile_map.map_to_local(used_rect.position) - half_tile
	var bottom_right_px = tile_map.map_to_local(used_rect.end - Vector2i(1, 1)) + half_tile
	
	# 1. 玩家出生点：地图正中心
	if spawn_point:
		spawn_point.global_position = (top_left_px + bottom_right_px) / 2.0
	
	# 2. 传送门：右下角 (往内偏移 1.5 个格子，避免紧贴墙壁)
	if home_portal:
		var portal_pos = bottom_right_px - Vector2(tile_size.x * 1.5, tile_size.y * 1.5)
		home_portal.global_position = portal_pos

## [导航烘焙] 刷新寻路网格
func _bake_navigation_mesh() -> void:
	if nav_region:
		nav_region.bake_navigation_polygon()
		
	# 【新增】一切就绪，通知大管家拉开黑幕！
	GameManager.scene_ready_to_reveal.emit()
#endregion
