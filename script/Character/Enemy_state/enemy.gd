extends CharacterBase
class_name Enemy

## Enemy.gd
## 这是一个“黑板”类，只负责持有数据和通用物理，不负责状态切换逻辑。

#region 1. AI 配置
@export_group("AI Settings")
@export var attack_distance: float = 120.0      ## 攻击触发距离
@export var retreat_distance: float = 70.0      ## 后退距离 (防粘连)
@export var aggro_trigger_time: float = 1.0     ## 仇恨触发时间
@export var aggro_lose_time: float = 3.0        ## 仇恨丢失时间
#endregion

#region 2. 攻击配置
@export_group("Attack Settings")
@export var attack_damage: int = 20
@export var attack_range_length: float = 150.0  ## 攻击框长度
@export var attack_width: float = 60.0          ## 攻击框宽度
@export var charge_duration: float = 1.0        ## 蓄力(前摇)时间
@export var attack_cooldown: float = 2.0        ## 冷却时间
#endregion

#region 共享数据 (供状态机读写)
var is_aggro_active: bool = false       ## 是否处于仇恨状态
var aggro_timer: float = 0.0            ## 仇恨计时器
var attack_pivot: Node2D                ## 攻击旋转轴
var attack_visual: ColorRect            ## 攻击红框
var attack_area: Area2D                 ## 攻击判定区
#endregion

func _ready() -> void:
	super._ready()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_setup_attack_nodes() # 初始化攻击判定框

func _physics_process(delta: float) -> void:
	super._physics_process(delta) # 父类处理击退衰减
	
	# 1. 索敌 (父类逻辑)
	_update_target_logic(delta)
	
	# 2. 计算仇恨 (这是通用规则，不属于某个特定状态)
	_update_aggro_system(delta)
	
	# 3. 物理融合
	# 状态机(State) 只负责修改 self.velocity 的“意图部分”
	# Enemy 本体负责叠加环境力(分离/推挤) + 击退力
	var env_force = _calculate_environment_forces()
	velocity += env_force + knockback_velocity
	
	# 击退保护
	if knockback_velocity.length_squared() > 2500.0:
		velocity = knockback_velocity
		
	move_and_slide()

#region 通用工具方法 (供 State 调用)
## 辅助方法：面向目标
func face_current_target() -> void:
	if not is_instance_valid(current_target) or not sprite: return
	var diff_x = current_target.global_position.x - global_position.x
	if abs(diff_x) < 1.0: return 
	var default_facing = -1 if flipped_horizontal else 1
	sprite.scale.x = -default_facing if diff_x < 0 else default_facing

## 辅助方法：初始化攻击节点
func _setup_attack_nodes() -> void:
	attack_pivot = Node2D.new()
	add_child(attack_pivot)
	
	attack_visual = ColorRect.new()
	attack_pivot.add_child(attack_visual)
	attack_visual.color = Color(1.0, 0.2, 0.2, 0.6)
	attack_visual.visible = false
	attack_visual.position.y = -attack_width / 2.0
	attack_visual.size = Vector2(0, attack_width)
	
	attack_area = Area2D.new()
	attack_pivot.add_child(attack_area)
	attack_area.collision_layer = 0
	attack_area.collision_mask = 2 # 只检测玩家 Layer 2
	attack_area.monitoring = false
	
	var col = CollisionShape2D.new()
	attack_area.add_child(col)
	var rect = RectangleShape2D.new()
	rect.size = Vector2(attack_range_length, attack_width)
	col.shape = rect
	col.position = Vector2(attack_range_length / 2.0, 0)

## 辅助方法：仇恨计算
func _update_aggro_system(delta: float) -> void:
	if is_dead: return
	var has_target = false
	if is_instance_valid(current_target) and not current_target.is_dead:
		if enter_Character.has(current_target):
			has_target = true
	
	if has_target:
		if not is_aggro_active:
			aggro_timer += delta
			if aggro_timer >= aggro_trigger_time:
				is_aggro_active = true
		else:
			aggro_timer = aggro_lose_time
	else:
		if is_aggro_active:
			aggro_timer -= delta
			if aggro_timer <= 0:
				is_aggro_active = false
		else:
			aggro_timer = 0.0

func _update_target_logic(_delta: float) -> void:
	Target_Lock_On(current_target)
	if not is_instance_valid(current_target):
		current_target = get_closest_target()
		
func _calculate_environment_forces() -> Vector2:
	# (此处省略具体实现，请保留你原来的代码，因为它没有变)
	return super._calculate_environment_forces()
#endregion
