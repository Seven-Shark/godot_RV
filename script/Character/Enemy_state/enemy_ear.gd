extends Area2D
class_name EnemyEar

## 敌人听觉组件：检测玩家噪音并触发“调查声源”行为，不直接进入索敌。

#region 1. 听觉配置
@export var suspicion_threshold: float = 30.0 # 疑惑值阈值，超过才会响应
@export var listen_radius: float = 420.0 # 耳朵基础监听半径 (应大于视觉 DetectionArea)
@export var scan_interval: float = 0.15 # 扫描间隔，降低性能开销
@export var enemy: Enemy # 所属的敌人实体引用 (为空则自动获取父节点)
#endregion

#region 2. 内部状态数据
@onready var collision_shape: CollisionShape2D = $CollisionShape2D # 必须作为子节点存在的碰撞体
var _scan_timer: float = 0.0 # 扫描间隔的计时器
#endregion

#region 3. 生命周期与核心逻辑
# 初始化监听组件的绑定并更新碰撞体半径
func _ready() -> void:
	if not enemy:
		enemy = get_parent() as Enemy
	_update_shape_radius()

# 处理循环监听计时，检测玩家发出的噪音并判定是否触发警觉
func _process(delta: float) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead:
		return
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = scan_interval

	var player = get_tree().get_first_node_in_group("Player")
	# 使用鸭子类型检测方法是否存在，消除对 Player 内部组件结构的强耦合
	if not is_instance_valid(player) or not player.has_method("get_current_noise"):
		return

	var current_noise = player.get_current_noise()
	if current_noise < suspicion_threshold:
		return

	var dist = enemy.global_position.distance_to(player.global_position)
	if dist > listen_radius:
		return
	if not player.has_method("get_noise_radius"):
		return
	var noise_radius = player.get_noise_radius()
	if dist > noise_radius:
		return

	enemy.receive_noise_signal(player.global_position, current_noise)
#endregion

#region 4. 辅助方法
# 动态获取或生成圆形碰撞体，并根据配置的监听半径更新其大小
func _update_shape_radius() -> void:
	if not collision_shape:
		push_error("EnemyEar 组件缺少 CollisionShape2D 子节点！")
		return
	var shape = collision_shape.shape as CircleShape2D
	if not shape:
		shape = CircleShape2D.new()
		collision_shape.shape = shape
	shape.radius = listen_radius
#endregion
