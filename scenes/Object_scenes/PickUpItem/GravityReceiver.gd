extends Node
class_name GravityReceiver

## 引力接收组件 (GravityReceiver) - 子节点脚本
##
## 职责：
## 1. [物理接管]：接管父节点的运动控制，使其飞向目标。
## 2. [运动计算]：计算加速度、速度和位移。
## 3. [结算触发]：当距离足够近时，触发资源收集逻辑并销毁对象。
##
## 使用要求：
## 必须作为 RigidBody2D 的子节点挂载。

#region 1. 飞行参数配置
@export_group("Gravity Settings")
@export var acceleration: float = 4500.0   ## [配置] 飞行加速度 (数值越大，吸过去越快)
@export var collect_distance: float = 20.0 ## [配置] 收集判定距离 (小于此距离视为吃到)
#endregion

#region 2. 内部状态
var is_active: bool = false       ## [状态] 是否处于激活(吸附)状态
var target_node: Node2D = null    ## [状态] 吸引源 (玩家或枪口)
var current_speed: float = 0.0    ## [状态] 当前飞行速度
var parent_body: RigidBody2D      ## [引用] 父节点 (我们要移动的对象)
#endregion

#region 生命周期
func _ready() -> void:
	# 1. 获取父节点，并进行类型安全检查
	# 这个组件必须挂在 RigidBody2D 下面才能工作
	parent_body = get_parent() as RigidBody2D
	
	if not parent_body:
		push_error("GravityReceiver: 父节点不是 RigidBody2D！组件已失效。")
		set_physics_process(false) # 停止运行以节省性能
		return

func _physics_process(delta: float) -> void:
	# 只有激活时才运行每帧的移动逻辑
	if is_active:
		_process_movement(delta)
#endregion

#region 核心功能 (API) - 供父节点调用

## [接口] 激活吸附模式
## [param target]: 吸引源
func activate(target: Node2D):
	if is_active: return # 防止重复激活
	
	is_active = true
	target_node = target
	current_speed = 100.0 # 初始初速度，避免起步太慢显得卡顿
	
	# 修改父节点的物理状态：
	# 1. 关闭碰撞：防止飞行过程中卡在墙里
	# 2. 冻结物理：完全由本脚本的代码接管位移，不让物理引擎干涉
	if parent_body:
		parent_body.collision_layer = 0
		parent_body.collision_mask = 0
		parent_body.freeze = true

#endregion

#region 内部逻辑

## [运动] 处理每帧的飞行位移
func _process_movement(delta: float):
	# 1. 容错检查：如果父节点被销毁了，或者目标(玩家)没了
	if not is_instance_valid(parent_body) or not is_instance_valid(target_node):
		_self_destruct()
		return
		
	# 2. 计算方向：从父节点指向目标
	var direction = (target_node.global_position - parent_body.global_position).normalized()
	
	# 3. 计算速度：v = v0 + at (持续加速)
	current_speed += acceleration * delta
	
	# 4. 应用位移：直接修改父节点的全局位置
	parent_body.global_position += direction * current_speed * delta
	
	# 5. 距离检测：判断是否接触到目标
	var dist = parent_body.global_position.distance_to(target_node.global_position)
	if dist <= collect_distance:
		_trigger_collect()

## [结算] 触发资源收集逻辑
func _trigger_collect():
	# TODO: 在这里对接你的全局背包系统
	# 比如: InventoryManager.add_item(parent_body.item_id, 1)
	
	# 目前使用之前提到的临时逻辑
	GameDataManager.add_temp_resource(1)
	
	# print("资源收集成功！")
	
	# 销毁父节点 (也就是把金币删掉)
	_self_destruct()

## [辅助] 自毁逻辑
func _self_destruct():
	if parent_body:
		parent_body.queue_free()
	else:
		queue_free()

#endregion
