extends Node2D
class_name BuildComponent

## 建造核心组件 (附着于 Player)
## 职责：管理建造模式、虚影跟随、网格吸附与放置判定

#region 1. 信号与配置
signal build_mode_changed(is_active: bool) ## 通知 UI 建造模式开关
signal grid_snap_toggled(is_snapping: bool) ## 通知 UI 网格吸附状态

@export var grid_size: int = 32 ## 网格大小 (需与地图 TileSize 对应)
@export var obstacle_layers: int = 0b00010001 ## 障碍物检测层 (勾选环境和敌人所在的层)
#endregion

#region 2. 内部状态
var is_building_mode: bool = false
var is_grid_snap_on: bool = true ## 默认开启网格吸附
var is_placement_valid: bool = false

var current_recipe: BuildingRecipe = null
var player: CharacterBase

# 虚影节点
var ghost_root: Node2D
var ghost_sprite: Sprite2D
var ghost_area: Area2D
var ghost_collider: CollisionShape2D
#endregion

#region 3. 生命周期
func _ready() -> void:
	player = get_parent() as CharacterBase
	_setup_ghost_nodes()

func _process(_delta: float) -> void:
	if not is_building_mode or not is_instance_valid(player): return
	
	_update_ghost_transform()
	_check_placement_validity()
#endregion

#region 4. 虚影与物理初始化
## [初始化] 动态生成虚影相关的物理和视觉节点
func _setup_ghost_nodes() -> void:
	ghost_root = Node2D.new()
	ghost_root.visible = false
	
	ghost_sprite = Sprite2D.new()
	ghost_root.add_child(ghost_sprite)
	
	ghost_area = Area2D.new()
	ghost_area.collision_mask = obstacle_layers # 只检测障碍物
	ghost_root.add_child(ghost_area)
	
	ghost_collider = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	ghost_collider.shape = shape
	ghost_area.add_child(ghost_collider)
	
	# 将虚影加到顶级，脱离 Player 的 Transform 限制
	call_deferred("add_child", ghost_root)
	ghost_root.set_as_top_level(true)
#endregion

#region 5. 核心计算逻辑
## [空间数学] 更新虚影的位置与旋转 (包含网格吸附逻辑)
func _update_ghost_transform() -> void:
	# 1. 计算玩家面向的基础点
	var facing_dir = Vector2.RIGHT
	# 如果你的 Player 有获取朝向的方法，例如：
	if player.get("direction_Sign"): 
		facing_dir = Vector2.RIGHT.rotated(player.direction_Sign.rotation)
	elif player.velocity.length_squared() > 0.1:
		facing_dir = player.velocity.normalized()
		
	var target_pos = player.global_position + facing_dir * current_recipe.build_distance
	
	# 2. 网格吸附核心算法
	if is_grid_snap_on:
		target_pos = target_pos.snapped(Vector2(grid_size, grid_size))
		# 如果你的 TileMap 原点在中心，可能需要加上半个网格的偏移：
		# target_pos += Vector2(grid_size/2.0, grid_size/2.0)
	
	ghost_root.global_position = target_pos
	
	# 建筑物通常不需要随意旋转，如果需要，取消下方注释
	# ghost_root.rotation = facing_dir.angle() 

## [物理检测] 检查虚影是否与环境重叠
func _check_placement_validity() -> void:
	var overlaps = ghost_area.get_overlapping_bodies()
	
	is_placement_valid = true
	for body in overlaps:
		if body != player: # 排除玩家自己
			is_placement_valid = false
			break
			
	# 视觉反馈
	if is_placement_valid:
		ghost_sprite.modulate = Color(0.2, 1.0, 0.2, 0.6) # 半透明绿
	else:
		ghost_sprite.modulate = Color(1.0, 0.2, 0.2, 0.6) # 半透明红
#endregion

#region 6. 交互与控制接口
## [接口] UI 点击配方时调用
func enter_build_mode(recipe: BuildingRecipe) -> void:
	current_recipe = recipe
	is_building_mode = true
	
	ghost_sprite.texture = recipe.ghost_texture
	(ghost_collider.shape as RectangleShape2D).size = recipe.collision_size
	ghost_root.visible = true
	
	build_mode_changed.emit(true)
	grid_snap_toggled.emit(is_grid_snap_on)
	print(">>> [BuildComponent] 进入建造模式: ", recipe.building_name)

func exit_build_mode() -> void:
	is_building_mode = false
	current_recipe = null
	ghost_root.visible = false
	build_mode_changed.emit(false)
	print(">>> [BuildComponent] 退出建造模式")

func _place_building() -> void:
	if not is_placement_valid or not current_recipe.prefab:
		print(">>> [BuildComponent] 无法放置：位置非法或无预制体")
		# 可以在这里播放个错误提示音
		return
		
	# 1. 扣除资源 (假设你有全局数据系统)
	# GameDataManager.spend_resources(current_recipe)
	
	# 2. 实例化并放置
	var building_instance = current_recipe.prefab.instantiate()
	# 扔到当前场景的合适容器里 (例如 LevelManager 的 object_container)
	get_tree().current_scene.add_child(building_instance)
	building_instance.global_position = ghost_root.global_position
	# building_instance.rotation = ghost_root.rotation
	
	print(">>> [BuildComponent] 放置成功: ", current_recipe.building_name)
	exit_build_mode() # 放置后退出，或者不清空继续连续建造
#endregion

#region 7. 输入拦截 (Input)
func _unhandled_input(event: InputEvent) -> void:
	if not is_building_mode: return
	
	# Q键：切换网格吸附
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		is_grid_snap_on = not is_grid_snap_on
		grid_snap_toggled.emit(is_grid_snap_on)
		get_viewport().set_input_as_handled()
		
	# Shift键：取消建造
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SHIFT:
		exit_build_mode()
		get_viewport().set_input_as_handled()
		
	# E键：确认放置 (拦截默认的交互)
	elif GameInputEvents.is_interact_event(event):
		_place_building()
		get_viewport().set_input_as_handled() # 拦截事件，防止触发传送门等
#endregion
