extends WorldEntity
class_name NestEntity

## NestEntity.gd
## 职责：继承自 WorldEntity，专门负责“刷怪笼”逻辑。
## 功能：定时生成敌人、配置生成权重、注入 AI 巡逻参数。

#region 巢穴生成配置
@export_group("Nest Settings")
@export var spawn_options: Array[SpawnOption] = [] ## 可生成的敌人列表
@export var spawn_interval: float = 5.0            ## 生成间隔(秒)
@export var spawn_count_per_wave: int = 1          ## 每次生成数量
@export var max_total_spawns: int = -1             ## 最大生成总数 (-1为无限)
@export var spawn_radius_min: float = 60.0         ## 生成位置最小半径 (防卡墙)
@export var spawn_radius_max: float = 120.0        ## 生成位置最大半径
@export var spawn_patrol_radius: float = 400.0     ## 赋予敌人的巡逻半径
#endregion

# 内部状态
var _spawn_timer: float = 0.0
var _current_spawned_count: int = 0

func _ready() -> void:
	# [重要] 必须先调用父类的初始化，确保物理、血量、类型设置正确
	super._ready()
	
	# 强制设置类型为 NEST (防止你在 Inspector 里忘选)
	entity_type = EntityType.NEST
	# 重新初始化一下物理，因为类型可能变了
	_init_physics_state()

func _process(delta: float) -> void:
	# 如果巢穴已经被摧毁（父类的 _is_dying 标志），停止生成
	if _is_dying: return
	
	# 执行生成循环
	_process_nest_spawning(delta)

#region 生成逻辑
func _process_nest_spawning(delta: float):
	if max_total_spawns != -1 and _current_spawned_count >= max_total_spawns:
		return
		
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_spawn_wave()

func _spawn_wave():
	if spawn_options.is_empty(): return
	
	for i in range(spawn_count_per_wave):
		if max_total_spawns != -1 and _current_spawned_count >= max_total_spawns:
			break
			
		var enemy_scene = _pick_random_enemy_by_weight()
		if enemy_scene:
			_instantiate_enemy(enemy_scene)

func _pick_random_enemy_by_weight() -> PackedScene:
	var total_weight = 0.0
	for opt in spawn_options:
		total_weight += opt.weight
	
	var rng = randf() * total_weight
	var current_weight = 0.0
	
	for opt in spawn_options:
		current_weight += opt.weight
		if rng <= current_weight:
			return opt.enemy_scene
	
	return spawn_options[0].enemy_scene if not spawn_options.is_empty() else null

func _instantiate_enemy(scene: PackedScene):
	var enemy = scene.instantiate() as Enemy
	if not enemy: return
	
	# 1. 计算生成位置
	var angle = randf() * TAU
	var dist = randf_range(spawn_radius_min, spawn_radius_max)
	var spawn_pos = global_position + Vector2(cos(angle), sin(angle)) * dist
	
	# 2. 添加到场景 (加到当前巢穴的父节点下，通常是 YSort 节点)
	get_parent().add_child(enemy)
	enemy.global_position = spawn_pos
	
	# 3. [关键] 注入 AI 参数：围绕本巢穴巡逻
	enemy.spawn_position = global_position      # 巡逻中心 = 巢穴位置
	enemy.patrol_radius = spawn_patrol_radius   # 巡逻半径
	enemy.patrol_mode = Enemy.PatrolMode.FIXED_AREA # 强制设为定点模式
	
	# 4. 计数
	_current_spawned_count += 1
#endregion
