extends RigidBody2D
class_name WorldEntity

## WorldEntity.gd
## 职责：作为所有可交互物体的基类 (父类)。
## 功能：管理物理状态、血量、掉落、受击反馈。

#region 信号定义
signal visuals_hit_requested(dir: Vector2)
signal visuals_death_requested
signal visuals_gravity_process(attractor: Vector2)
signal visuals_launch_requested(start: Vector2, end: Vector2)
signal visuals_absorb_requested(target: Node2D)
signal visuals_recover_requested
#endregion

#region 1. 类型与配置
enum EntityType {
	PROP,     ## [物件]：树、矿石
	RESOURCE, ## [资源]：木头、金币
	HEAVY,    ## [重物]：炸药桶
	NEST      ## [巢穴]：虽然逻辑在子类，但保留枚举方便外部识别
}

enum ObjectMaterial {
	WOOD, STONE, METAL, RUBBER, GHOST, NONE
}

@export_group("Entity Identity")
@export var entity_type: EntityType = EntityType.PROP
@export var material_type: ObjectMaterial = ObjectMaterial.WOOD

@export_group("Physics")
@export var mass_override: float = 10.0

@export_group("Loot")
@export var loot_table: Array[LootData] = []
@export var drop_radius: float = 60.0

# 物理层级常量
const LAYER_PROP_MASK = 1 << 2  # Layer 3
const LAYER_RESOURCE_MASK = 1 << 3 # Layer 4
#endregion

#region 2. 内部状态
@onready var stats: StatsComponent = get_node_or_null("StatsComponent")
var _is_absorbed: bool = false
var _is_dying: bool = false
#endregion

#region 生命周期
func _ready() -> void:
	mass = mass_override
	_init_physics_state()
	
	if entity_type == EntityType.HEAVY:
		add_to_group("Heavy")
	
	# 连接血量组件
	if stats:
		stats.died.connect(_on_death)

## [核心] 初始化物理状态
func _init_physics_state():
	match entity_type:
		EntityType.PROP, EntityType.NEST: 
			freeze = true 
			freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
			collision_layer = LAYER_PROP_MASK
			# 碰撞掩码：地形(1) | 敌人(2) | 物件(3)
			collision_mask = 1 | 2 | 4 
			_apply_material()
			
		EntityType.RESOURCE:
			freeze = true
			collision_layer = 0
			collision_mask = 0
			gravity_scale = 0.0
			
		EntityType.HEAVY:
			freeze = false
			linear_damp = 5.0
			collision_layer = LAYER_PROP_MASK
			_apply_material()

func _apply_material():
	var phys_mat = PhysicsMaterial.new()
	match material_type:
		ObjectMaterial.RUBBER: phys_mat.bounce = 0.8; phys_mat.friction = 0.5
		ObjectMaterial.STONE:  phys_mat.bounce = 0.0; phys_mat.friction = 1.0
		ObjectMaterial.WOOD:   phys_mat.bounce = 0.2; phys_mat.friction = 0.8
		ObjectMaterial.METAL:  phys_mat.bounce = 0.1; phys_mat.friction = 0.4
	physics_material_override = phys_mat
#endregion

#region 交互接口 (供 Weapon 调用)
func take_damage(amount: float, _attacker_type: int, attacker_node: Node2D = null):
	if entity_type == EntityType.RESOURCE: return 
	
	if stats: stats.take_damage(amount)
	
	if attacker_node:
		var dir = (global_position - attacker_node.global_position).normalized()
		visuals_hit_requested.emit(dir)

func start_absorbing(target: Node2D):
	# 巢穴和重物不可被吸附
	if entity_type == EntityType.HEAVY or entity_type == EntityType.NEST: return 
	
	if _is_absorbed: return
	_is_absorbed = true
	collision_layer = 0
	collision_mask = 0
	freeze = true
	visuals_absorb_requested.emit(target)

func apply_gravity_visual(attractor_pos: Vector2):
	if entity_type == EntityType.PROP:
		visuals_gravity_process.emit(attractor_pos)

func recover_from_gravity():
	if entity_type == EntityType.HEAVY: freeze = false
	visuals_recover_requested.emit()

func launch(start: Vector2, end: Vector2):
	visuals_launch_requested.emit(start, end)

func enable_pickup_detection():
	if entity_type != EntityType.RESOURCE: return
	if _is_absorbed: return
	collision_layer = LAYER_RESOURCE_MASK
	collision_mask = 0
	freeze = false 

func collect_success():
	GameDataManager.add_temp_resource(1)
	queue_free()
#endregion

#region 内部逻辑 (死亡与掉落)
# 只要是继承 WorldEntity 的，死亡都会走这里
func _on_death():
	if _is_dying: return
	_is_dying = true
	
	visuals_death_requested.emit()
	
	# 可以在子类覆盖此方法，或者在这里做通用处理
	call_deferred("_spawn_loot")

func _spawn_loot():
	if loot_table.is_empty(): 
		await get_tree().create_timer(0.2).timeout
		queue_free()
		return

	for loot in loot_table:
		if not loot or not loot.item_scene: continue
		var count = loot.get_drop_count()
		for i in range(count):
			var item = loot.item_scene.instantiate()
			get_parent().add_child(item)
			var angle = randf() * TAU
			var target_pos = global_position + Vector2.RIGHT.rotated(angle) * randf_range(20, drop_radius)
			if item.has_method("launch"):
				item.launch(global_position, target_pos)
	
	queue_free()
#endregion
