extends RigidBody2D
class_name WorldEntity

## 世界实体基类 (WorldEntity)
##
## 职责：
## 1. [数据]：定义实体类型、管理物理状态、物理材质。
## 2. [交互]：处理受击、吸附、悬停等外部交互接口。
## 3. [生命周期]：管理死亡与掉落生成。

#region 信号定义 (指挥 VisualController)
# --- 物件 (PROP) 相关 ---
signal visuals_hit_requested(dir: Vector2)          ## 请求受击震动
signal visuals_death_requested                      ## 请求死亡动画
signal visuals_gravity_process(attractor: Vector2)  ## [新增] 请求引力悬停抖动

# --- 资源 (RESOURCE) 相关 ---
signal visuals_launch_requested(start: Vector2, end: Vector2) ## 请求爆出抛物线动画
signal visuals_absorb_requested(target: Node2D)     ## 请求吸附飞行

# --- 通用/重物 (HEAVY) 相关 ---
signal visuals_recover_requested                    ## 请求恢复物理或重置动画状态
#endregion

#region 1. 类型与配置
enum EntityType {
	PROP,     ## [物件]：树、矿石。有血量、有物理材质、产出掉落物、受引力悬停。
	RESOURCE, ## [资源]：木头、金币。无血量、无碰撞(初始)、被吸附时飞入背包。
	HEAVY     ## [重物]：炸药桶。有物理碰撞、被吸附时卡在枪口。
}

enum ObjectMaterial {
	WOOD, STONE, METAL, RUBBER, GHOST, NONE
}

@export_group("Entity Identity")
@export var entity_type: EntityType = EntityType.PROP   ## [关键] 决定实体的行为模式
@export var material_type: ObjectMaterial = ObjectMaterial.WOOD ## [关键] 物理材质类型

@export_group("Physics")
@export var mass_override: float = 10.0                 ## 质量覆盖

@export_group("Loot (Only for PROP)")
@export var loot_table: Array[LootData] = []            ## 掉落表配置
@export var drop_radius: float = 60.0                   ## 掉落散布半径

# 物理层级常量 (使用位移运算修正)
# Layer 3 (Environment/Prop) = 2^(3-1) = 4 (二进制 100)
const LAYER_PROP_MASK = 1 << 2  
# Layer 4 (Items/Resource) = 2^(4-1) = 8 (二进制 1000)
const LAYER_RESOURCE_MASK = 1 << 3 
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
	
	# 自动分组 (方便引力枪识别重物)
	if entity_type == EntityType.HEAVY:
		add_to_group("Heavy")
	
	# 连接血量组件 (仅 PROP 有效)
	if entity_type == EntityType.PROP and stats:
		stats.died.connect(_on_death)

## [核心] 初始化物理状态
func _init_physics_state():
	match entity_type:
		EntityType.PROP:
			freeze = true # 默认静止
			# [修正] 使用位掩码赋值
			collision_layer = LAYER_PROP_MASK
			# Mask 通常保留 Layer 2 (World/Player) 等交互
			_apply_material()
			
		EntityType.RESOURCE:
			freeze = true # 资源初始冻结，等待 Launch 动画
			collision_layer = 0 # 初始无碰撞，防止乱撞
			collision_mask = 0
			gravity_scale = 0.0
			
		EntityType.HEAVY:
			freeze = false # 重物受物理引擎控制
			linear_damp = 5.0 # 增加阻尼防止滑行过远
			# [修正] 使用位掩码赋值
			collision_layer = LAYER_PROP_MASK
			_apply_material()

## 应用物理材质参数
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

## 1. 承受伤害 (PROP 专属)
# [注意] 为了兼容旧代码，这里保留了 _attacker_type 参数位
func take_damage(amount: float, _attacker_type: int, attacker_node: Node2D = null):
	# print(">>> [WorldEntity] %s 受到伤害: %s" % [name, amount])
	if entity_type != EntityType.PROP: return
	
	# 数值处理
	if stats: stats.take_damage(amount)
	
	# 视觉反馈
	if attacker_node:
		var dir = (global_position - attacker_node.global_position).normalized()
		visuals_hit_requested.emit(dir)

## 2. 开始吸附 (RESOURCE 专属)
# 注意：重物吸附由引力枪直接控制物理，不走此逻辑
func start_absorbing(target: Node2D):
	if entity_type == EntityType.HEAVY: return 
	
	if _is_absorbed: return
	_is_absorbed = true
	
	# 关闭物理，移交控制权给 VisualController
	collision_layer = 0
	collision_mask = 0
	freeze = true
	
	visuals_absorb_requested.emit(target)

## 3. 应用引力悬停视觉 (PROP 专属)
# [新增] 当引力波持续作用于物件时调用
func apply_gravity_visual(attractor_pos: Vector2):
	if entity_type == EntityType.PROP:
		visuals_gravity_process.emit(attractor_pos)

## 4. 恢复状态 (通用)
# 用于重物放下，或物件从悬停中恢复
func recover_from_gravity():
	if entity_type == EntityType.HEAVY:
		freeze = false
	
	# 通知 VisualController 复位动画
	visuals_recover_requested.emit()

## 5. 爆出启动 (RESOURCE 专属)
# 通常由生成该资源的 Spawner 调用
func launch(start: Vector2, end: Vector2):
	visuals_launch_requested.emit(start, end)

## 6. 开启捡起检测 (由 Visual 回调)
func enable_pickup_detection():
	# [修复 3] 只有资源才能开启“被捡起”的物理层级
	# 如果是 PROP (比如生成的小石头)，落地后应该保持 PROP 的物理状态，不能变成可捡起状态
	if entity_type != EntityType.RESOURCE: return
	
	if _is_absorbed: return
	
	# [修正] 使用位掩码赋值
	collision_layer = LAYER_RESOURCE_MASK
	collision_mask = 0
	freeze = true

## 7. 收集结算 (由 Visual 回调)
func collect_success():
	# 对接全局数据管理器
	GameDataManager.add_temp_resource(1)
	queue_free()
#endregion

#region 内部逻辑 (死亡与掉落)
func _on_death():
	if _is_dying: return
	_is_dying = true
	
	visuals_death_requested.emit()
	
	# 延迟执行掉落，防止物理报错 (Flushing Queries Error)
	call_deferred("_spawn_loot")

func _spawn_loot():
	if loot_table.is_empty(): 
		# 如果没有掉落物，稍作延迟后销毁 (等待死亡动画播放)
		await get_tree().create_timer(0.2).timeout
		queue_free()
		return

	for loot in loot_table:
		
		# [修复 1] 检查 loot 数据本身是否存在
		if not loot: continue
		
		# [修复 2] 关键检查：检查 Item Scene 是否为空！
		# 如果你在检查器里忘了把木头/石头的场景拖进去，这里就会拦截并警告，而不是报错崩溃
		if not loot.item_scene:
			push_warning("[%s] 的掉落表中有一项缺少 Item Scene！已跳过。" % name)
			continue
		
		var count = loot.get_drop_count()
		for i in range(count):
			var item = loot.item_scene.instantiate()
			get_parent().add_child(item) # 此时已在 deferred 中，操作安全
			
			# 计算随机落点
			var angle = randf() * TAU
			var target_pos = global_position + Vector2.RIGHT.rotated(angle) * randf_range(20, drop_radius)
			
			# 启动掉落物的动画
			if item.has_method("launch"):
				item.launch(global_position, target_pos)
	
	queue_free()
#endregion
