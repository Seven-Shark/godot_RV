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
var is_grid_snap_on: bool = false ## 默认开启网格吸附
var is_placement_valid: bool = false

# 使用通用的 CraftingRecipe
var current_recipe: CraftingRecipe = null
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
	ghost_root.name = "GhostRoot"
	ghost_root.visible = false
	ghost_root.z_index = 100 # 确保在最上层
	
	ghost_sprite = Sprite2D.new()
	ghost_sprite.name = "GhostSprite"
	# 设置虚影透明度
	ghost_sprite.modulate = Color(1, 1, 1, 0.6)
	ghost_root.add_child(ghost_sprite)
	
	ghost_area = Area2D.new()
	ghost_area.name = "GhostArea"
	ghost_area.collision_mask = obstacle_layers # 只检测障碍物
	ghost_area.monitorable = false # 虚影本身不应该被检测
	ghost_root.add_child(ghost_area)
	
	ghost_collider = CollisionShape2D.new()
	ghost_collider.name = "GhostCollider"
	var shape = RectangleShape2D.new()
	ghost_collider.shape = shape
	ghost_area.add_child(ghost_collider)
	
	# 将虚影加到当前场景根节点下，避免被 Player 节点遮挡或随 Player 旋转
	if get_tree().current_scene:
		get_tree().current_scene.call_deferred("add_child", ghost_root)
	else:
		# Fallback: 如果没有 current_scene (例如独立运行 Player 场景测试)，则加到 BuildComponent 下并 top_level
		call_deferred("add_child", ghost_root)
		ghost_root.set_as_top_level(true)
#endregion

#region 5. 核心计算逻辑
## [空间数学] 更新虚影的位置与旋转 (包含网格吸附逻辑)
func _update_ghost_transform() -> void:
	# 1. 计算玩家面向的基础点 (始终位于角色面前 40 距离)
	var facing_dir = Vector2.RIGHT
	# 如果你的 Player 有获取朝向的方法，例如：
	if player.get("direction_Sign"): 
		facing_dir = Vector2.RIGHT.rotated(player.direction_Sign.rotation)
	elif player.velocity.length_squared() > 0.1:
		facing_dir = player.velocity.normalized()
	
	# 固定距离 40
	var target_pos = player.global_position + facing_dir * 40.0
	
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
		ghost_sprite.modulate = Color(0.2, 0.2, 1.0, 0.6) # 蓝色 (可建造)
	else:
		ghost_sprite.modulate = Color(1.0, 0.2, 0.2, 0.6) # 红色 (不可建造)
#endregion

#region 6. 交互与控制接口
## [接口] UI 点击配方时调用
func enter_build_mode(recipe: CraftingRecipe) -> void:
	if not recipe or not recipe.result_item or not recipe.result_item.build_prefab:
		push_warning("配方无效或缺少建筑预制体")
		return
		
	current_recipe = recipe
	is_building_mode = true
	
	ghost_sprite.texture = recipe.result_item.icon
	# 暂时使用固定碰撞大小，或者从 ItemData/Prefab 中获取
	(ghost_collider.shape as RectangleShape2D).size = Vector2(32, 32) 
	ghost_root.visible = true
	
	build_mode_changed.emit(true)
	grid_snap_toggled.emit(is_grid_snap_on)
	print(">>> [BuildComponent] 进入建造模式: ", recipe.result_item.item_name)

func exit_build_mode() -> void:
	is_building_mode = false
	current_recipe = null
	if ghost_root:
		ghost_root.visible = false
	build_mode_changed.emit(false)
	print(">>> [BuildComponent] 退出建造模式")

func _place_building() -> void:
	if not is_placement_valid or not current_recipe:
		print(">>> [BuildComponent] 无法放置：位置非法或无配方")
		return
		
	# 1. 扣除资源
	# 检查资源是否足够
	for stack in current_recipe.ingredients:
		if GameDataManager.get_item_count(stack.item.id) < stack.count:
			print(">>> [BuildComponent] 资源不足: ", stack.item.item_name)
			return

	# 扣除
	for stack in current_recipe.ingredients:
		GameDataManager.remove_item(stack.item.id, stack.count)
	
	# 2. 实例化并放置
	var building_instance = current_recipe.result_item.build_prefab.instantiate()
	# 扔到当前场景的合适容器里 (例如 LevelManager 的 object_container)
	get_tree().current_scene.add_child(building_instance)
	building_instance.global_position = ghost_root.global_position
	# building_instance.rotation = ghost_root.rotation
	
	print(">>> [BuildComponent] 放置成功: ", current_recipe.result_item.item_name)
	exit_build_mode() # 放置后退出
#endregion

#region 7. 输入拦截 (Input)
func _unhandled_input(event: InputEvent) -> void:
	if not is_building_mode: return
	
	# Q键：切换网格吸附 (可选)
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		is_grid_snap_on = not is_grid_snap_on
		grid_snap_toggled.emit(is_grid_snap_on)
		get_viewport().set_input_as_handled()
		
	# ESC键：取消建造
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		exit_build_mode()
		get_viewport().set_input_as_handled()
		
	# E键：确认放置 (拦截默认的交互)
	elif GameInputEvents.is_interact_event(event):
		_place_building()
		get_viewport().set_input_as_handled() # 拦截事件，防止触发传送门等
#endregion
