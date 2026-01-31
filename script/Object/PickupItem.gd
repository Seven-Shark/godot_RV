extends RigidBody2D
class_name PickupItem

## 掉落物基类 (PickupItem) - 根节点 (数据层)
##
## 职责：
## 1. [数据]：定义物品类型、物理参数。
## 2. [状态]：管理物理状态 (冻结/开启碰撞)。
## 3. [接口]：作为对外交互入口，通过信号指挥子组件工作。

#region 信号定义
## 通知子组件：开始播放爆出动画
signal launch_requested(start_pos: Vector2, target_pos: Vector2)
## 通知子组件：开始被吸附动画
signal absorb_requested(target: Node2D)
#endregion

#region 1. 类型定义与配置
enum ItemType {
	RESOURCE, ## [资源]：飞向背包，无物理碰撞
	HEAVY     ## [重物]：卡在枪口，有物理碰撞 (不由本脚本处理吸附)
}

const TARGET_LAYER_VALUE: int = 8          ## [配置] 落地后的碰撞层级
@export var item_type: ItemType = ItemType.RESOURCE ## [关键] 物品类型
#endregion

#region 2. 渲染层级
@export_group("Rendering")
@export var target_z_index: int = -1       ## [视觉] 图片渲染层级
#endregion

#region 3. 内部状态
var _is_absorbed: bool = false             ## [状态] 是否正在被吸附
#endregion

#region 生命周期
func _ready() -> void:
	# 1. 自动分组
	if item_type == ItemType.HEAVY:
		add_to_group("Heavy")
	
	# 2. 初始化物理
	_init_physics_state()
	z_index = target_z_index

## [初始化] 设置物理状态
func _init_physics_state():
	if item_type == ItemType.RESOURCE:
		# 资源模式：完全冻结，等待动画控制
		freeze = true 
		collision_layer = 0 
		collision_mask = 0
		gravity_scale = 0.0 
		linear_damp = 0.0
	else:
		# 重物模式：开启物理
		freeze = false 
		collision_layer = TARGET_LAYER_VALUE 
		collision_mask = 1 | 2
		gravity_scale = 0.0 
		linear_damp = 5.0
	
	lock_rotation = true
	y_sort_enabled = true
#endregion

#region 核心接口 (API)

## [接口] 发起爆出流程
## 由 Spawner 调用，负责发出信号，让动画组件干活
func launch(start_pos: Vector2, target_pos: Vector2):
	if item_type == ItemType.HEAVY:
		global_position = target_pos
		return
	
	# 发出信号，通知 Visual 组件开始播放动画
	launch_requested.emit(start_pos, target_pos)

## [接口] 开启捡起检测
## 由 Visual 组件在动画播放完毕后回调
func enable_pickup_detection():
	if _is_absorbed: return
	
	collision_layer = TARGET_LAYER_VALUE
	collision_mask = 0
	freeze = true

## [接口] 开始被吸附
## 由 Weapon 调用
func start_absorbing(target: Node2D):
	# 重物拒绝执行
	if item_type == ItemType.HEAVY: return
	if _is_absorbed: return
	
	_is_absorbed = true
	
	# 关闭物理，准备让动画组件接管位移
	collision_layer = 0
	collision_mask = 0
	freeze = true
	
	# 发出信号，通知 Visual 组件接管移动
	absorb_requested.emit(target)

## [接口] 收集结算
## 由 Visual 组件在吸附完成后调用
func collect_success():
	# 对接数据系统
	GameDataManager.add_temp_resource(1)
	queue_free()

## [接口] 重物恢复
func recover_from_gravity():
	if item_type == ItemType.HEAVY:
		freeze = false
		linear_damp = 5.0

#endregion
