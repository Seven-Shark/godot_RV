extends Area2D
class_name EnemyEar

## 敌人听觉组件：检测玩家噪音并触发“调查声源”行为，不直接进入索敌。

#region 1. 听觉配置
## 疑惑值阈值，超过才会响应
@export var suspicion_threshold: float = 30.0 # 疑惑值阈值，超过才会响应
## 耳朵基础监听半径（应大于 DetectionArea）
@export var listen_radius: float = 420.0 # 耳朵基础监听半径（应大于 DetectionArea）
## 扫描间隔，降低开销
@export var scan_interval: float = 0.15 # 扫描间隔，降低开销
#endregion

#region 2. 内部状态数据
var _enemy: Enemy = null # 所属的敌人实体节点引用
var _scan_timer: float = 0.0 # 扫描间隔的计时器
#endregion

#region 3. 生命周期与核心逻辑
# 初始化监听组件的绑定并更新碰撞体半径
func _ready() -> void:
	_enemy = get_parent() as Enemy
	_update_shape_radius()

# 处理循环监听计时，检测玩家发出的噪音并判定是否触发警觉
func _process(delta: float) -> void:
	if not _enemy or _enemy.is_dead:
		return
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = scan_interval

	var player = get_tree().get_first_node_in_group("Player") # 场景中的玩家节点引用
	if not player:
		return
	var stats = player.get_node_or_null("StatsComponent") as CharacterStatsComponent # 玩家的属性组件引用
	if not stats:
		return

	if stats.current_noise_value < suspicion_threshold:
		return

	var dist = _enemy.global_position.distance_to(player.global_position) # 敌人当前位置与玩家的物理距离
	if dist > listen_radius:
		return
	if dist > stats.current_noise_radius:
		return

	_enemy.receive_noise_signal(player.global_position, stats.current_noise_value)
#endregion

#region 4. 辅助方法
# 动态获取或生成圆形碰撞体，并根据配置的监听半径更新其大小
func _update_shape_radius() -> void:
	var collider = get_node_or_null("CollisionShape2D") as CollisionShape2D # 碰撞形状组件引用
	if not collider:
		return
	var shape = collider.shape as CircleShape2D # 具体的圆形形状资源引用
	if not shape:
		shape = CircleShape2D.new()
		collider.shape = shape
	shape.radius = listen_radius
#endregion
