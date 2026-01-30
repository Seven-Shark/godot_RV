extends RigidBody2D
class_name PickupItem

## 掉落物基类 (PickupItem) - 根节点脚本
##
## 职责：
## 1. [数据定义]：定义物品类型(资源/重物)、物理参数、渲染层级。
## 2. [视觉表现]：负责生成时的抛物线跳跃动画、弹性形变。
## 3. [接口代理]：作为武器交互的入口，将吸附逻辑转发给子组件 (GravityReceiver)。
##
## 架构说明：
## 本脚本挂载于 RigidBody2D 根节点。
## 具体的吸附飞行逻辑，请挂载子节点组件 GravityReceiver。

#region 1. 类型定义与配置
enum ItemType {
	RESOURCE, ## [资源模式]：无物理碰撞，默认冻结，被吸附时飞入背包 (委托给子组件)
	HEAVY     ## [重物模式]：有物理碰撞，被吸附时卡在枪口 (由引力枪直接控制)
}

const TARGET_LAYER_VALUE: int = 8          ## [配置] 资源落地后开启检测时的碰撞层级
@export var item_type: ItemType = ItemType.RESOURCE ## [关键] 当前物品类型
#endregion

#region 2. 渲染与层级
@export_group("Rendering")
@export var target_z_index: int = -1       ## [视觉] 图片渲染层级 (建议-1，位于角色脚下)
#endregion

#region 3. 动画配置 (仅资源模式生效)
@export_group("Animation Settings")
@export var jump_height: float = 40.0           ## 爆出时的跳跃高度
@export var start_scale_ratio: Vector2 = Vector2.ZERO  ## 初始缩放 (从无到有)
@export var stretch_ratio: Vector2 = Vector2(1.2, 1.2) ## 拉伸比例
@export var squash_ratio: Vector2 = Vector2(0.9, 0.7)  ## 挤压比例
@export var anim_duration_min: float = 0.4      ## 动画时长下限
@export var anim_duration_max: float = 0.6      ## 动画时长上限
#endregion

#region 4. 组件引用
## [核心] 获取处理引力交互的子组件
## 这是一个"组合"模式的应用，具体的飞行运算交给子节点
@onready var gravity_component: GravityReceiver = get_node_or_null("GravityReceiver")
@onready var sprite: Node2D = get_node_or_null("Sprite2D")
#endregion

#region 生命周期
func _ready() -> void:
	# 1. 自动分组：如果是重物，加入 "Heavy" 组供引力枪识别
	if item_type == ItemType.HEAVY:
		add_to_group("Heavy")
	
	# 2. 初始化物理状态
	_init_physics_state()
	
	# 3. 设置层级
	z_index = target_z_index

## [初始化] 根据类型设置物理参数
func _init_physics_state():
	if item_type == ItemType.RESOURCE:
		# --- 资源模式 ---
		# 默认冻结，完全由代码/动画控制位移
		freeze = true 
		collision_layer = 0 
		collision_mask = 0
		gravity_scale = 0.0 
		linear_damp = 0.0
	else:
		# --- 重物模式 ---
		# 开启物理模拟
		freeze = false 
		collision_layer = TARGET_LAYER_VALUE 
		collision_mask = 1 | 2 # 假设与环境(1)和玩家(2)碰撞
		gravity_scale = 0.0 # 俯视角无重力
		linear_damp = 5.0   # [重要] 增加阻尼模拟地面摩擦
	
	lock_rotation = true
	y_sort_enabled = true
#endregion

#region 核心功能 (API) - 供外部调用

## [动画] 执行抛物线爆出动画
## [param start_pos]: 出生点
## [param target_pos]: 落地点
func launch(start_pos: Vector2, target_pos: Vector2):
	# 重物通常不需要Q弹动画，直接出现即可
	if item_type == ItemType.HEAVY:
		global_position = target_pos
		return
	
	# --- 资源模式动画 ---
	global_position = start_pos
	if not sprite: return
	
	var original_scale = sprite.scale 
	var tween = create_tween()
	var duration = randf_range(anim_duration_min, anim_duration_max)
	
	# 1. 位移
	tween.tween_property(self, "global_position", target_pos, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. 形变
	_animate_jump(duration)
	_animate_squash_stretch(duration, original_scale)

	await tween.finished
	
	# 动画结束落地后，检查组件状态
	# 如果组件没有在工作(即没被吸走)，则开启碰撞检测允许捡起
	if not _is_being_absorbed():
		_enable_pickup_detection()

## [交互接口] 开始被引力吸附
## 武器脚本调用 body.start_absorbing(target) 时触发
func start_absorbing(target: Node2D):
	# 1. 重物模式：拒绝执行
	# 重物由引力枪的 _capture_object 直接控制物理，不需要子组件介入
	if item_type == ItemType.HEAVY:
		return
		
	# 2. 资源模式：转发给子组件
	if gravity_component:
		gravity_component.activate(target)
	else:
		# 容错处理：如果忘了挂子组件，就销毁自己防止Bug，或者打印错误
		push_warning("PickupItem: 缺少 GravityReceiver 子组件，无法吸附！")

## [交互接口] 从引力枪控制中恢复
## 武器放下重物时调用
func recover_from_gravity():
	if item_type == ItemType.HEAVY:
		freeze = false       # 恢复物理
		linear_damp = 5.0    # 恢复阻尼
		# 可以在此重置碰撞层级

#endregion

#region 内部辅助逻辑

## [状态检查] 查询子组件是否正在工作
func _is_being_absorbed() -> bool:
	if gravity_component:
		return gravity_component.is_active
	return false

## [物理] 落地后开启检测 (仅资源)
func _enable_pickup_detection():
	# 如果正在被吸，或者组件已激活，就不开物理了
	if _is_being_absorbed(): return
	
	collision_layer = TARGET_LAYER_VALUE
	collision_mask = 0
	freeze = true 

## [动画] 跳跃 (Y轴偏移)
func _animate_jump(duration: float):
	if not sprite: return
	var t = create_tween()
	t.tween_property(sprite, "position:y", -jump_height, duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(sprite, "position:y", 0.0, duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## [动画] 弹性形变
func _animate_squash_stretch(duration: float, base_scale: Vector2):
	if not sprite: return
	sprite.scale = base_scale * start_scale_ratio
	var t = create_tween()
	t.tween_property(sprite, "scale", base_scale * stretch_ratio, duration * 0.7)
	t.chain().tween_property(sprite, "scale", base_scale * squash_ratio, 0.1)
	t.chain().tween_property(sprite, "scale", base_scale, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
#endregion
