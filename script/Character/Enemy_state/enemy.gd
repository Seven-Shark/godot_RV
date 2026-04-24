extends CharacterBase
class_name Enemy

## Enemy.gd
## 职责：处理敌人的数据中心、环境力、攻击判定、高级巡逻逻辑，以及弱点击破系统。
## 功能：管理 AI 仇恨状态，支持寻路避障系统，严格处理导航地图同步，包含多阶段定向弱点系统。

#region 1. 巡逻模式与 AI 配置
@export_group("Patrol Settings")
## 巡逻模式
@export var patrol_mode: PatrolMode = PatrolMode.GLOBAL_RANDOM # 巡逻模式
## 巡逻半径 (固定区域模式下的总活动半径)
@export var patrol_radius: float = 300.0 # 巡逻半径 (固定区域模式下的总活动半径)
## 单次移动最小距离
@export var patrol_wander_min: float = 100.0 # 单次移动最小距离
## 单次移动最大距离
@export var patrol_wander_max: float = 300.0 # 单次移动最大距离
## 最大追击距离
@export var max_chase_distance: float = 500.0 # 最大追击距离
## 最小等待时间
@export var patrol_wait_min: float = 1.0 # 最小等待时间
## 最大等待时间
@export var patrol_wait_max: float = 3.0 # 最大等待时间
## 空气墙的物理层级 (默认 Layer 5)
@export_flags_2d_physics var wall_layer_mask: int = 16 # 空气墙的物理层级 (默认 Layer 5)

@export_subgroup("Stuck Detection")
## 防卡死检测半径
@export var stuck_check_radius: float = 20.0 # 防卡死检测半径
## 第一阶段：尝试换个随机点的时间
@export var stuck_retry_time: float = 2.0 # 第一阶段：尝试换个随机点的时间
## 第二阶段：强制反向逃逸的时间 (累加在第一阶段后)
@export var stuck_escape_time: float = 1.5 # 第二阶段：强制反向逃逸的时间 (累加在第一阶段后)
## 通用导航卡住判定的最小位移阈值
@export var nav_stuck_min_move_distance: float = 2.5 # 通用导航卡住判定的最小位移阈值
## 通用导航触发绕行的时间阈值
@export var nav_stuck_trigger_time: float = 0.35 # 通用导航触发绕行的时间阈值
## 绕行阶段持续时间
@export var nav_detour_duration: float = 0.28 # 绕行阶段持续时间
## 侧向探测宽度（模拟敌人肩膀，防止侧边卡住）
@export var nav_probe_side_offset: float = 18.0 # 侧向探测宽度（模拟敌人肩膀，防止侧边卡住）
## 绕行阶段侧向探测距离
@export var nav_detour_probe_distance: float = 28.0 # 绕行阶段侧向探测距离
## 绕行阶段最大侧向探测距离 (用于大体积障碍)
@export var nav_detour_probe_max_distance: float = 120.0 # 绕行阶段最大侧向探测距离 (用于大体积障碍)
## 绕行阶段前向混合权重
@export var nav_detour_forward_weight: float = 0.35 # 绕行阶段前向混合权重
## 绕行阶段最长持续时间上限
@export var nav_detour_max_duration: float = 0.75 # 绕行阶段最长持续时间上限
## 导航阻挡检测层级 (默认包含 Layer 3 物件与 Layer 5 空气墙)
@export_flags_2d_physics var nav_block_mask: int = 20 # 导航阻挡检测层级
## 主动滑行探测距离
@export var nav_slide_probe_distance: float = 32.0 # 主动滑行探测距离
## 切线滑行前向混合权重
@export var nav_slide_forward_weight: float = 0.2 # 切线滑行前向混合权重
## 判定“严重卡住”后切换临时绕路点的时间阈值
@export var nav_hard_stuck_time: float = 1.1 # 判定“严重卡住”后切换临时绕路点的时间阈值
## 临时绕路点最小半径
@export var nav_bypass_radius_min: float = 80.0 # 临时绕路点最小半径
## 临时绕路点最大半径
@export var nav_bypass_radius_max: float = 260.0 # 临时绕路点最大半径
## 判定到达临时绕路点的距离阈值
@export var nav_bypass_reach_distance: float = 18.0 # 判定到达临时绕路点的距离阈值

@export_group("AI Settings")
## 攻击触发距离
@export var attack_distance: float = 120.0 # 攻击触发距离
## 后退距离
@export var retreat_distance: float = 70.0 # 后退距离
## 仇恨触发时间
@export var aggro_trigger_time: float = 1.0 # 仇恨触发时间
## 仇恨丢失时间
@export var aggro_lose_time: float = 3.0 # 仇恨丢失时间

@export_group("Physics Forces")
## 分离力度 (软碰撞)
@export var separation_force: float = 500.0 # 分离力度 (软碰撞)
## 推挤力度
@export var push_force: float = 800.0 # 推挤力度
## 推挤半径
@export var push_threshold: float = 80.0 # 推挤半径

@export_group("Debug Visualization")
## 显示巡逻范围调试信息
@export var show_patrol_area: bool = false # 显示巡逻范围调试信息
## 显示移动路径连线
@export var show_path_line: bool = false # 显示移动路径连线
@export_group("Alert Indicator")
## 敌人脱离锁定后“省略号”提示持续时间
@export var alert_lost_lock_duration: float = 1.2 # 敌人脱离锁定后“省略号”提示持续时间
## 敌人头顶提示文本颜色
@export var alert_text_color: Color = Color(1.0, 0.95, 0.6, 1.0) # 敌人头顶提示文本颜色
## 是否在地图上显示最后发声点标记
@export var show_last_sound_point_marker: bool = true # 是否在地图上显示最后发声点标记
## 最后发声点标记颜色
@export var last_sound_point_marker_color: Color = Color(0.25, 0.95, 1.0, 0.9) # 最后发声点标记颜色
## 最后发声点标记半径
@export var last_sound_point_marker_radius: float = 8.0 # 最后发声点标记半径
const EAR_SCENE_PATH := "res://scenes/characterBase_scenes/EnemyEar.tscn"
#endregion

#region 1.1 昼夜行为倍率配置
@export_group("Phase Behavior Multipliers")
@export_subgroup("Day")
## 白天移动速度倍率
@export var day_move_speed_mul: float = 0.8 # 白天移动速度倍率
## 白天攻击速度倍率 (>1 表示更慢)
@export var day_attack_speed_mul: float = 1.25 # 白天攻击速度倍率 (>1 表示更慢)
## 白天巡逻距离倍率
@export var day_patrol_distance_mul: float = 0.75 # 白天巡逻距离倍率
## 白天感知范围倍率
@export var day_perception_mul: float = 1.0 # 白天感知范围倍率

@export_subgroup("Dusk")
## 黄昏移动速度倍率
@export var dusk_move_speed_mul: float = 0.8 # 黄昏移动速度倍率
## 黄昏攻击速度倍率
@export var dusk_attack_speed_mul: float = 1.25 # 黄昏攻击速度倍率
## 黄昏巡逻距离倍率
@export var dusk_patrol_distance_mul: float = 1.25 # 黄昏巡逻距离倍率
## 黄昏感知范围倍率
@export var dusk_perception_mul: float = 1.0 # 黄昏感知范围倍率

@export_subgroup("Night")
## 夜晚移动速度倍率
@export var night_move_speed_mul: float = 1.3 # 夜晚移动速度倍率
## 夜晚攻击速度倍率 (<1 表示更快)
@export var night_attack_speed_mul: float = 0.7 # 夜晚攻击速度倍率 (<1 表示更快)
## 夜晚巡逻距离倍率
@export var night_patrol_distance_mul: float = 1.25 # 夜晚巡逻距离倍率
## 夜晚感知范围倍率 (放大一倍)
@export var night_perception_mul: float = 2.0 # 夜晚感知范围倍率 (放大一倍)
#endregion

#region 2. 攻击配置
@export_group("Attack Settings")
## 攻击框长度
@export var attack_range_length: float = 150.0 # 攻击框长度
## 攻击框宽度
@export var attack_width: float = 60.0 # 攻击框宽度
## 蓄力时间
@export var charge_duration: float = 1.0 # 蓄力时间
## 冷却时间
@export var attack_cooldown: float = 2.0 # 冷却时间
## 攻击目标层级
@export_flags_2d_physics var attack_target_mask: int = 1 # 攻击目标层级
#endregion

#region 3. 弱点击破系统配置 (Weakness System)
@export_group("Weakness System")
## 是否开启弱点系统
@export var enable_weakness: bool = true # 是否开启弱点系统
## 玩家靠近多近时显示弱点
@export var weakness_trigger_dist: float = 400.0 # 玩家靠近多近时显示弱点
## 弱点圆弧在敌人身上绘制的半径
@export var weakness_draw_radius: float = 40.0 # 弱点圆弧在敌人身上绘制的半径
## 破绽各阶段的弧度大小(度数)
@export var weakness_stages: Array[float] = [120.0, 90.0, 60.0] # 破绽各阶段的弧度大小(度数)
## 每次刷新弱点时，和上次位置的最小角度差
@export var weakness_min_angle_diff: float = 90.0 # 每次刷新弱点时，和上次位置的最小角度差
## 所有弱点击破后的眩晕时间
@export var weakness_stun_duration: float = 2.5 # 所有弱点击破后的眩晕时间

var is_weakness_active: bool = false # 弱点是否正在显示
var is_stunned: bool = false # 敌人是否处于破绽击破后的眩晕状态
var current_weakness_stage: int = 0 # 当前打到了第几个破绽阶段
var current_weakness_angle: float = 0.0 # 当前破绽的朝向角度 (弧度)
#endregion

#region 4. 内部共享数据
enum PatrolMode { GLOBAL_RANDOM, FIXED_AREA } # 巡逻枚举定义

var is_aggro_active: bool = false # 是否处于仇恨激活状态
var aggro_timer: float = 0.0 # 仇恨计时器
var spawn_position: Vector2 # 初始出生点
var is_returning: bool = false # 是否正在强制返航
var current_patrol_target: Vector2 = Vector2.ZERO # 当前巡逻目标坐标点
var is_separation_active: bool = true # 是否开启分离力避让

var attack_pivot: Node2D # 攻击方向基准点
var attack_visual: ColorRect # 攻击范围预览
var attack_area: Area2D # 攻击判定区域
@onready var state_machine: NodeStateMachine = get_node_or_null("StateMachine") # 状态机引用
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D # 导航代理组件

var _phase_move_speed_mul: float = 1.0 # 当前昼夜阶段的移动速度倍率
var _phase_attack_speed_mul: float = 1.0 # 当前昼夜阶段的攻击速度倍率
var _phase_patrol_distance_mul: float = 1.0 # 当前昼夜阶段的巡逻距离倍率
var _phase_perception_mul: float = 1.0 # 当前昼夜阶段的感知范围倍率

var _base_patrol_radius: float = 0.0 # 缓存的基础巡逻半径
var _base_patrol_wander_min: float = 0.0 # 缓存的基础单次移动最小距离
var _base_patrol_wander_max: float = 0.0 # 缓存的基础单次移动最大距离
var _base_charge_duration: float = 0.0 # 缓存的基础蓄力时间
var _base_detection_scale: Vector2 = Vector2.ONE # 缓存的基础感知区域缩放倍数

var is_noise_investigating: bool = false # 当前是否在执行噪音调查
var noise_investigate_target: Vector2 = Vector2.ZERO # 当前记录的最后发声点
@onready var alert_label: Label = $AlertLabel # 敌人头顶状态提示文本
var _alert_lost_lock_timer: float = 0.0 # 脱离锁定后的省略号计时器
var _was_aggro_active: bool = false # 记录上一帧是否处于锁定状态

var _nav_stuck_timer: float = 0.0 # 通用导航卡住计时器
var _nav_prev_position: Vector2 = Vector2.ZERO # 通用导航上一帧位置
var _nav_detour_timer: float = 0.0 # 通用导航绕行剩余时间
var _nav_detour_direction: Vector2 = Vector2.ZERO # 通用导航绕行方向
var _nav_detour_side_sign: int = 1 # 通用导航绕行左右方向交替符号
var _nav_hard_stuck_timer: float = 0.0 # 严重卡住累计计时器
var _nav_bypass_active: bool = false # 是否正在执行临时绕路
var _nav_bypass_target: Vector2 = Vector2.ZERO # 当前临时绕路目标点
#endregion

#region 5. 生命周期与核心循环
# 初始化生命周期及组件绑定
func _ready() -> void:
	super._ready()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_setup_attack_nodes()
	_ensure_ear_node()
	_setup_alert_label()
	_cache_base_phase_stats()
	_bind_day_phase_events()
	
	if nav_agent:
		nav_agent.path_desired_distance = 20.0
		nav_agent.target_desired_distance = 10.0
		if not nav_agent.velocity_computed.is_connected(_on_nav_velocity_computed):
			nav_agent.velocity_computed.connect(_on_nav_velocity_computed)
	
	spawn_position = global_position 
	current_patrol_target = global_position
	
	await get_tree().physics_frame
	await get_tree().physics_frame

# 物理帧处理循环，处理状态驱动与物理结算
func _physics_process(delta: float) -> void:
	queue_redraw()
	_update_alert_indicator(delta)
	
	if is_stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	_process_weakness_trigger()

	if is_returning:
		_process_return_logic(delta)
		move_and_slide()
		return 

	super._physics_process(delta)
	_update_target_logic(delta)
	_update_aggro_system(delta)
	_sync_last_sound_point_during_aggro()
	
	var env_force = _calculate_environment_forces() # 当前环境合力
	velocity += env_force + knockback_velocity
	
	if knockback_velocity.length_squared() > 2500.0: velocity = knockback_velocity
		
	if patrol_mode == PatrolMode.FIXED_AREA and is_aggro_active:
		if global_position.distance_to(spawn_position) > max_chase_distance:
			start_forced_return()
			
	move_and_slide()

# 处理调试信息与弱点系统的可视化绘制
func _draw() -> void:
	if show_patrol_area and patrol_mode == PatrolMode.FIXED_AREA:
		var center_local = to_local(spawn_position) # 转换为本地坐标的中心点
		draw_circle(center_local, 5.0, Color.GREEN)
		draw_arc(center_local, patrol_radius, 0, TAU, 64, Color.GREEN, 1.0)
		draw_arc(center_local, max_chase_distance, 0, TAU, 64, Color.RED, 1.5)

	if show_path_line:
		var real_destination = Vector2.ZERO # 实际寻路终点
		if is_returning: real_destination = spawn_position
		elif is_instance_valid(current_target) and not current_target.is_dead: real_destination = current_target.global_position
		elif current_patrol_target != Vector2.ZERO: real_destination = current_patrol_target
		
		if real_destination != Vector2.ZERO:
			var target_local = to_local(real_destination) # 终点的本地坐标
			var line_color = Color.YELLOW # 默认连线颜色
			if is_returning: line_color = Color.CYAN
			elif is_instance_valid(current_target): line_color = Color.ORANGE_RED 
			draw_line(Vector2.ZERO, target_local, line_color, 2.0)

	if show_last_sound_point_marker and noise_investigate_target != Vector2.ZERO and not is_dead:
		var sound_point_local = to_local(noise_investigate_target) # 最后发声点的本地坐标
		var marker_radius = max(2.0, last_sound_point_marker_radius) # 防止半径过小不可见
		draw_circle(sound_point_local, marker_radius, last_sound_point_marker_color)
		draw_arc(sound_point_local, marker_radius + 4.0, 0.0, TAU, 32, last_sound_point_marker_color, 2.0)
			
	if enable_weakness and is_weakness_active and not is_stunned and not is_dead:
		if current_weakness_stage < weakness_stages.size():
			var arc_angle_rad = deg_to_rad(weakness_stages[current_weakness_stage]) # 弱点弧度值
			var start_angle = current_weakness_angle - (arc_angle_rad / 2.0) # 绘制起始角度
			
			draw_arc(Vector2.ZERO, weakness_draw_radius, start_angle, start_angle + arc_angle_rad, 16, Color(1, 0, 0, 0.4), 4.0)
			draw_arc(Vector2.ZERO, weakness_draw_radius + 2.0, start_angle, start_angle + arc_angle_rad, 16, Color.YELLOW, 2.0)
#endregion

#region 6. 弱点击破系统逻辑
# 负责检测玩家距离，控制弱点的显示与隐藏
func _process_weakness_trigger() -> void:
	if not enable_weakness: return
	
	if is_dead:
		is_weakness_active = false
		return
		
	if is_stunned: return
	
	if not is_instance_valid(current_target) or current_target.is_dead:
		is_weakness_active = false
		return
		
	var dist = global_position.distance_to(current_target.global_position) # 距目标距离
	
	if dist <= weakness_trigger_dist and not is_weakness_active:
		is_weakness_active = true
		current_weakness_stage = 0
		_refresh_weakness_position()
	elif dist > weakness_trigger_dist + 50.0 and is_weakness_active:
		is_weakness_active = false

# 刷新弱点位置，并确保与上一次位置有足够的角度差
func _refresh_weakness_position() -> void:
	var new_angle = current_weakness_angle # 新生成的弱点角度
	var min_diff_rad = deg_to_rad(weakness_min_angle_diff) # 最小差值弧度
	var max_attempts = 10 # 最大尝试次数
	
	for i in range(max_attempts):
		new_angle = randf() * TAU
		if abs(angle_difference(current_weakness_angle, new_angle)) >= min_diff_rad:
			break
			
	current_weakness_angle = new_angle

# 重写受到伤害函数，额外进行破绽方向判定
func take_damage(amount: int, attacker_type: CharacterType, attacker_node: Node2D = null) -> void:
	super(amount, attacker_type, attacker_node)
	
	if enable_weakness and is_weakness_active and not is_stunned and not is_dead and attacker_node:
		var dir_to_attacker = (attacker_node.global_position - global_position).normalized() # 朝向攻击者的向量
		var attack_angle = dir_to_attacker.angle() # 攻击角度
		var angle_diff = abs(angle_difference(current_weakness_angle, attack_angle)) # 攻击角度差
		var current_arc_rad = deg_to_rad(weakness_stages[current_weakness_stage]) # 当前阶段有效击破弧度
		
		if angle_diff <= current_arc_rad / 2.0:
			_on_weakness_hit()

# 处理弱点被击中后的阶段递增逻辑
func _on_weakness_hit() -> void:
	print(">>> [弱点系统] 击破破绽！当前阶段: ", current_weakness_stage + 1)
	current_weakness_stage += 1
	
	if current_weakness_stage >= weakness_stages.size():
		_trigger_weakness_stun()
	else:
		_refresh_weakness_position()

# 触发破绽全破的终极眩晕及状态打断
func _trigger_weakness_stun() -> void:
	print(">>> [弱点系统] 破绽全破！敌人陷入眩晕！")
	is_stunned = true
	is_weakness_active = false
	
	if attack_area: attack_area.set_deferred("monitoring", false)
	if attack_visual: attack_visual.visible = false
	
	if state_machine:
		if state_machine.has_node("Stun"): 
			state_machine.transition_to("Stun")
		else:
			state_machine.transition_to("Idle")
			
	await get_tree().create_timer(weakness_stun_duration).timeout
	
	if not is_dead:
		is_stunned = false
		current_weakness_stage = 0
		print(">>> [弱点系统] 眩晕结束，恢复正常。")
		if state_machine: state_machine.transition_to("Idle")
#endregion

#region 7. 寻路与避障系统
# 设置通用的导航目标点
func set_navigation_target(target_pos: Vector2) -> void:
	if nav_agent: nav_agent.target_position = target_pos

# 获取追击态实际导航目标：优先临时绕路点，未激活时使用玩家位置
func get_chase_navigation_target(chase_target_pos: Vector2) -> Vector2:
	if _nav_bypass_active:
		if global_position.distance_to(_nav_bypass_target) <= nav_bypass_reach_distance:
			_nav_bypass_active = false
			_nav_bypass_target = Vector2.ZERO
		else:
			return _nav_bypass_target
	return chase_target_pos

# 获取新巡逻点并设置为导航目标
func set_navigation_target_to_patrol_point() -> void:
	var next_point = get_next_patrol_point() # 获取的下一个巡逻点
	set_navigation_target(next_point)

# 处理导航移动计算，包含卡死检测与切线滑行
func process_navigation_movement(speed: float) -> bool:
	if not nav_agent: return true
	if nav_agent.is_navigation_finished():
		_reset_navigation_recovery_state()
		velocity = Vector2.ZERO
		return true

	# 1. 如果正在执行短时绕行（Detour）
	if _nav_detour_timer > 0.0:
		_apply_navigation_detour_motion(speed)
		_update_navigation_stuck_recovery(speed)
		return false

	# 2. 获取常规寻路方向
	nav_agent.max_speed = max(1.0, speed)
	var next_path_pos = nav_agent.get_next_path_position() # 下一个寻路路径点
	var forward_dir = (next_path_pos - global_position).normalized() # 前进方向向量

	# 3. [核心] 障碍物滑行检测 (针对圆形障碍物优化)
	var blocked_hit = _get_forward_navigation_block_hit(forward_dir) # 探测前方是否有物理阻挡
	if not blocked_hit.is_empty():
		# 如果探测到阻挡，构建切线速度，强制敌人“滑过去”
		var slide_velocity = _build_obstacle_slide_velocity(forward_dir, speed, blocked_hit) 
		if slide_velocity.length_squared() > 1.0:
			_apply_movement_velocity(slide_velocity)
			_update_navigation_stuck_recovery(speed) # 滑行中依然监控是否位移
			return false
	
	# 4. 正常寻路移动
	_apply_movement_velocity(forward_dir * speed)
	_update_navigation_stuck_recovery(speed)
	return false

# 内部方法：应用速度并处理视觉转向
func _apply_movement_velocity(new_velocity: Vector2) -> void:
	if sprite:
		if new_velocity.x > 0.1: sprite.scale.x = 1
		elif new_velocity.x < -0.1: sprite.scale.x = -1
	
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(new_velocity) # 走避障流程
	else:
		velocity = new_velocity # 直接赋值

# 建立滑行速度向量：利用障碍物法线计算切线方向
func _build_obstacle_slide_velocity(forward_dir: Vector2, speed: float, hit: Dictionary) -> Vector2:
	var hit_normal = hit.get("normal", Vector2.ZERO) as Vector2 # 障碍物表面法线
	if hit_normal == Vector2.ZERO: return Vector2.ZERO
	
	# 计算切线方向（即沿着圆形边缘的方向）
	var tangent_dir = Vector2(-hit_normal.y, hit_normal.x) # 基础左切线
	
	# 决定往左滑还是往右滑（取与前进方向夹角更小的那个）
	if forward_dir.dot(tangent_dir) < 0:
		tangent_dir = -tangent_dir
	
	# 混合前向力和切向力，形成“贴着圆弧滑行”的效果
	var slide_dir = (tangent_dir + forward_dir * 0.3).normalized()
	return slide_dir * speed

# 多射线前向探测：模拟敌人宽度，防止侧滑卡死
func _get_forward_navigation_block_hit(forward_dir: Vector2) -> Dictionary:
	var space_state = get_world_2d().direct_space_state # 物理状态引用
	var side_vec = Vector2(-forward_dir.y, forward_dir.x) * nav_probe_side_offset # 侧向偏移向量
	
	# 三向探测：左、中、右
	var probes = [
		global_position, 
		global_position + side_vec, 
		global_position - side_vec
	]
	
	for start_pos in probes:
		var query = PhysicsRayQueryParameters2D.create(
			start_pos, 
			start_pos + forward_dir * nav_slide_probe_distance, 
			nav_block_mask
		)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		if not result.is_empty():
			return result # 返回最先撞到的障碍信息
			
	return {}

# 通用导航卡住检测：当位移持续过小则进入短时绕行
func _update_navigation_stuck_recovery(speed: float) -> void:
	if speed <= 1.0 or is_dead or is_stunned:
		_reset_navigation_recovery_state()
		return
	if _nav_prev_position == Vector2.ZERO:
		_nav_prev_position = global_position
		return
	var moved_distance = global_position.distance_to(_nav_prev_position) # 本帧位移距离
	_nav_prev_position = global_position
	if moved_distance >= nav_stuck_min_move_distance:
		_nav_stuck_timer = 0.0
		_nav_hard_stuck_timer = 0.0
		return
	
	# 只有“前方路径被真实障碍阻挡”时才累计卡住时间
	if not _is_forward_path_blocked_for_navigation():
		_nav_stuck_timer = 0.0
		_nav_hard_stuck_timer = 0.0
		return
	_nav_stuck_timer += get_physics_process_delta_time()
	_nav_hard_stuck_timer += get_physics_process_delta_time()
	if _nav_stuck_timer >= nav_stuck_trigger_time:
		_start_navigation_detour()
		_nav_stuck_timer = 0.0
	if _nav_hard_stuck_timer >= nav_hard_stuck_time:
		_start_navigation_bypass_target()
		_nav_hard_stuck_timer = 0.0

# 启动短时侧向绕行，避免被 WorldEntity 或障碍物持续顶住
func _start_navigation_detour() -> void:
	var target_pos = nav_agent.target_position # 当前导航目标点
	var to_target = target_pos - global_position # 朝向目标的向量
	if to_target.length_squared() < 1.0:
		return
	var forward = to_target.normalized() # 前进方向
	var base_side = Vector2(-forward.y, forward.x) # 基础侧向方向
	var preferred_sign = _nav_detour_side_sign # 优先尝试的侧向符号
	_nav_detour_side_sign *= -1
	var base_probe = max(8.0, nav_detour_probe_distance) # 基础探测距离
	var max_probe = max(base_probe, nav_detour_probe_max_distance) # 最大探测距离
	var probe_factors = [1.0, 1.5, 2.0, 2.8, 3.6, 4.5, 6.0, 8.0] # 递增探测倍率 (支持大圈绕行)
	var selected_side = Vector2.ZERO # 选中的绕行侧向
	var selected_probe_dist = 0.0 # 选中的探测距离
	
	for factor in probe_factors:
		var probe_dist = min(max_probe, base_probe * factor)
		for sign in [preferred_sign, -preferred_sign]:
			var side = base_side * float(sign) # 当前尝试的侧向
			var probe_end = global_position + side * probe_dist # 侧向探测终点
			if _is_segment_blocked_for_navigation(global_position, probe_end):
				continue
			selected_side = side
			selected_probe_dist = probe_dist
			break
		if selected_probe_dist > 0.0:
			break
	
	if selected_probe_dist <= 0.0:
		return
	_nav_detour_direction = (selected_side + forward * max(0.0, nav_detour_forward_weight)).normalized()
	var duration_scale = selected_probe_dist / max(1.0, base_probe) # 距离越大，绕行持续越久
	_nav_detour_timer = min(nav_detour_max_duration, max(0.08, nav_detour_duration * duration_scale))

# 应用短时绕行动作，让导航代理有机会绕过近身障碍
func _apply_navigation_detour_motion(speed: float) -> void:
	_nav_detour_timer = max(0.0, _nav_detour_timer - get_physics_process_delta_time())
	var detour_velocity = _nav_detour_direction * max(1.0, speed) # 绕行速度
	_apply_movement_velocity(detour_velocity)

# 严重卡住时生成临时绕路目标点，避免在相邻障碍夹角内反复顶住
func _start_navigation_bypass_target() -> void:
	if not nav_agent:
		return
	var final_target = nav_agent.target_position # 最终目标点 (通常是玩家位置)
	var to_target = final_target - global_position # 指向最终目标的方向向量
	if to_target.length_squared() < 1.0:
		return
	var forward = to_target.normalized() # 追击前进方向
	var side = Vector2(-forward.y, forward.x) # 侧向基向量
	var radii = [nav_bypass_radius_min, (nav_bypass_radius_min + nav_bypass_radius_max) * 0.5, nav_bypass_radius_max] # 递进半径
	var angle_degrees = [35.0, -35.0, 60.0, -60.0, 85.0, -85.0, 120.0, -120.0] # 角度候选
	
	for radius in radii:
		var safe_radius = max(16.0, radius)
		for deg in angle_degrees:
			var dir = (forward.rotated(deg_to_rad(deg)) + side * 0.05).normalized() # 绕路方向候选
			var candidate = global_position + dir * safe_radius # 绕路点候选
			var map_rid = get_world_2d().get_navigation_map() # 导航地图 ID
			if NavigationServer2D.map_get_iteration_id(map_rid) == 0:
				continue
			var nav_point = NavigationServer2D.map_get_closest_point(map_rid, candidate) # 导航网格对齐点
			if nav_point.distance_to(candidate) > 20.0:
				continue
			if _is_segment_blocked_for_navigation(global_position, nav_point):
				continue
			_nav_bypass_target = nav_point
			_nav_bypass_active = true
			_nav_detour_timer = 0.0
			return

# 重置通用导航恢复器内部状态
func _reset_navigation_recovery_state() -> void:
	_nav_stuck_timer = 0.0
	_nav_hard_stuck_timer = 0.0
	_nav_prev_position = global_position
	_nav_detour_timer = 0.0
	_nav_detour_direction = Vector2.ZERO
	_nav_bypass_active = false
	_nav_bypass_target = Vector2.ZERO

# 检测前方短距离路径是否被阻挡 (用于卡住判定前置条件)
func _is_forward_path_blocked_for_navigation() -> bool:
	if not nav_agent:
		return false
	var next_path_pos = nav_agent.get_next_path_position() # 当前路径上的下一个导航点
	var to_next = next_path_pos - global_position # 指向下个导航点的向量
	if to_next.length_squared() < 1.0:
		return false
	var probe_dist = min(max(8.0, nav_detour_probe_distance), to_next.length()) # 前方探测距离
	var probe_end = global_position + to_next.normalized() * probe_dist # 前方探测终点
	return _is_segment_blocked_for_navigation(global_position, probe_end)

# 检测一段路径是否被导航障碍层阻挡
func _is_segment_blocked_for_navigation(start: Vector2, target: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state # 物理空间状态引用
	var query = PhysicsRayQueryParameters2D.create(start, target, nav_block_mask) # 阻挡检测射线参数
	query.exclude = [self] # 排除自身
	var result = space_state.intersect_ray(query) # 射线检测结果字典
	return not result.is_empty()

# 接收导航代理计算出的避障安全速度
func _on_nav_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity

# 获取下一个有效的巡逻点 (包含多重安全验证)
func get_next_patrol_point() -> Vector2:
	var map_rid = get_world_2d().get_navigation_map() # 导航地图 ID
	
	if NavigationServer2D.map_get_iteration_id(map_rid) == 0:
		return global_position

	var max_attempts = 15 # 选点最大尝试次数
	
	for i in range(max_attempts):
		var next_point = Vector2.ZERO # 临时目标点
		
		if patrol_mode == PatrolMode.FIXED_AREA:
			next_point = _get_random_point_in_range(spawn_position, 0.0, patrol_radius) 
		else:
			next_point = _get_random_point_in_range(global_position, patrol_wander_min, patrol_wander_max)
		
		if _is_position_inside_wall(next_point):
			continue 

		if not _is_point_safe_by_raycast(global_position, next_point):
			continue 
			
		var safe_point = NavigationServer2D.map_get_closest_point(map_rid, next_point) # 导航网格内安全点
		
		if next_point.distance_to(safe_point) > 5.0:
			continue 
			
		current_patrol_target = safe_point
		return safe_point

	return global_position

# 获取一个反向逃逸的巡逻点用于防卡死机制
func get_escape_patrol_point() -> Vector2:
	var forward_dir = Vector2.RIGHT # 默认向前方向
	
	if not nav_agent.is_navigation_finished():
		forward_dir = (nav_agent.get_next_path_position() - global_position).normalized()
	elif velocity.length_squared() > 1.0:
		forward_dir = velocity.normalized()
	
	var backward_base_dir = -forward_dir # 反向基准方向
	var max_attempts = 10 # 逃避点寻找次数
	var map_rid = get_world_2d().get_navigation_map() # 导航地图 ID
	
	for i in range(max_attempts):
		var random_angle = deg_to_rad(randf_range(-60, 60)) # 随机偏转弧度
		var escape_dir = backward_base_dir.rotated(random_angle) # 最终逃避向量
		var dist = randf_range(patrol_wander_min, patrol_wander_max) # 逃避距离
		var next_point = global_position + escape_dir * dist # 逃避目标点坐标
		
		if _is_position_inside_wall(next_point): continue 
		if not _is_point_safe_by_raycast(global_position, next_point): continue 
		var safe_point = NavigationServer2D.map_get_closest_point(map_rid, next_point) # 导航网格安全点
		if next_point.distance_to(safe_point) > 5.0: continue
		
		current_patrol_target = safe_point
		return safe_point

	return get_next_patrol_point()

# 检测某个点坐标是否完全处于墙体碰撞内部
func _is_position_inside_wall(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state # 物理空间状态引用
	var params = PhysicsPointQueryParameters2D.new() # 物理点查询参数
	params.position = pos
	params.collision_mask = wall_layer_mask 
	var results = space_state.intersect_point(params, 1) # 相交结果数组
	return not results.is_empty()

# 使用物理射线判断路径上是否存在空气墙遮挡
func _is_point_safe_by_raycast(start: Vector2, target: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state # 物理空间状态引用
	var query = PhysicsRayQueryParameters2D.create(start, target, wall_layer_mask) # 射线查询参数
	var result = space_state.intersect_ray(query) # 射线检测结果字典
	return result.is_empty()

# 触发强制返航状态逻辑
func start_forced_return() -> void:
	is_returning = true
	force_stop_aggro() 
	if state_machine: state_machine.transition_to("Return")

# 执行返航时的移动物理逻辑
func _process_return_logic(_delta: float) -> void:
	var dir = (spawn_position - global_position).normalized() # 返回原点的方向向量
	if stats: velocity = dir * get_runtime_base_speed() * 1.5
	if sprite:
		var default_facing = -1 if flipped_horizontal else 1 # 默认图片朝向校正
		if dir.x > 0: sprite.scale.x = default_facing
		elif dir.x < 0: sprite.scale.x = -default_facing
	if global_position.distance_to(spawn_position) < 10.0:
		is_returning = false
		velocity = Vector2.ZERO
		if state_machine: state_machine.transition_to("Idle")

# 辅助方法：在指定的圆环范围内获取随机点
func _get_random_point_in_range(center: Vector2, min_dist: float, max_dist: float) -> Vector2:
	var angle = randf() * TAU # 随机生成角度 
	var dist = randf_range(min_dist, max_dist) # 随机生成距离
	return center + Vector2(cos(angle), sin(angle)) * dist
#endregion

#region 8. 战斗与仇恨机制
# 强制清除仇恨目标并重置攻击相关组件与状态
func force_stop_aggro() -> void:
	is_aggro_active = false
	aggro_timer = 0.0
	current_target = null
	_reset_navigation_recovery_state()
	if attack_visual: attack_visual.visible = false
	if attack_area: attack_area.monitoring = false
	if state_machine and state_machine.has_method("reset"): state_machine.reset()

# 实时更新目标的有效性与重新锁定逻辑
func _update_target_logic(_delta: float) -> void:
	if is_instance_valid(current_target) and current_target.is_dead:
		force_stop_aggro(); return
	Target_Lock_On(current_target)
	if not is_instance_valid(current_target): current_target = get_closest_target()

# 让敌人视觉上翻转朝向当前锁定的目标
func face_current_target() -> void:
	if not is_instance_valid(current_target) or not sprite: 
		return
	var diff_x = current_target.global_position.x - global_position.x # 目标与自身的水平差值
	if abs(diff_x) < 5.0: 
		return
	if diff_x > 0: sprite.scale.x = 1 
	else: sprite.scale.x = -1 

# 动态初始化并配置攻击预览与判定节点
func _setup_attack_nodes() -> void:
	attack_pivot = Node2D.new(); add_child(attack_pivot)
	attack_visual = ColorRect.new(); attack_pivot.add_child(attack_visual)
	attack_visual.color = Color(1.0, 0.2, 0.2, 0.6); attack_visual.visible = false
	attack_visual.position.y = -attack_width / 2.0; attack_visual.size = Vector2(0, attack_width)
	attack_area = Area2D.new(); attack_pivot.add_child(attack_area)
	attack_area.collision_layer = 0; attack_area.collision_mask = attack_target_mask
	var col = CollisionShape2D.new(); attack_area.add_child(col) # 碰撞体节点
	var rect = RectangleShape2D.new(); rect.size = Vector2(attack_range_length, attack_width) # 矩形判定形状
	col.shape = rect; col.position = Vector2(attack_range_length / 2.0, 0)

# 更新仇恨计时系统及仇恨状态切换逻辑
func _update_aggro_system(delta: float) -> void:
	if is_dead: return
	var has_target = is_instance_valid(current_target) and not current_target.is_dead and enter_Character.has(current_target) # 当前目标状态判定
	if has_target:
		if not is_aggro_active:
			aggro_timer += delta
			if aggro_timer >= aggro_trigger_time:
				is_aggro_active = true
				is_noise_investigating = false
		else: aggro_timer = aggro_lose_time
	elif is_aggro_active:
		aggro_timer -= delta
		if aggro_timer <= 0:
			is_aggro_active = false
			current_target = null
			if noise_investigate_target != Vector2.ZERO:
				is_noise_investigating = true
				set_navigation_target(noise_investigate_target)

# 索敌期间持续刷新最后发声点，避免脱锁后使用旧点位
func _sync_last_sound_point_during_aggro() -> void:
	if not is_aggro_active:
		return
	if not is_instance_valid(current_target) or current_target.is_dead:
		return
	noise_investigate_target = current_target.global_position
#endregion

#region 9. 昼夜环境控制
# 根据当前昼夜倍率获取实时的基础移动速度
func get_runtime_base_speed() -> float:
	if not stats:
		return 100.0
	return stats.base_walk_speed * _phase_move_speed_mul

# 缓存各项属性的基础数值，以便受昼夜倍率动态影响
func _cache_base_phase_stats() -> void:
	_base_patrol_radius = patrol_radius
	_base_patrol_wander_min = patrol_wander_min
	_base_patrol_wander_max = patrol_wander_max
	_base_charge_duration = charge_duration
	if detection_Area:
		_base_detection_scale = detection_Area.scale

# 绑定全局游戏大管家的时间阶段切换信号
func _bind_day_phase_events() -> void:
	var director = _find_game_director() # 环境大管家节点
	if not director:
		return
	if director.has_signal("phase_changed") and not director.phase_changed.is_connected(_on_phase_changed):
		director.phase_changed.connect(_on_phase_changed)
	
	var phases = director.get("day_phases")
	var index_raw = director.get("current_phase_index")
	if phases is Array and index_raw != null:
		var idx = int(index_raw)
		if idx >= 0 and idx < phases.size():
			var cfg = phases[idx]
			if cfg is DayLoopConfig:
				_on_phase_changed(cfg)

# 在当前场景树中查找并返回 GameDirector 大管家节点
func _find_game_director() -> Node:
	var scene = get_tree().current_scene # 场景树根节点
	if not scene:
		return null
	var by_name = scene.get_node_or_null("GameDirector") # 基于名称获取的结果
	if by_name:
		return by_name
	var found = scene.find_children("*", "GameDirector", true, false) # 基于层级的深层搜索结果
	if found.size() > 0:
		return found[0]
	return null

# 响应昼夜阶段改变信号并应用对应的倍率配置
func _on_phase_changed(config: DayLoopConfig) -> void:
	match config.phase_type:
		DayLoopConfig.PhaseType.DAY:
			_apply_phase_profile(day_move_speed_mul, day_attack_speed_mul, day_patrol_distance_mul, day_perception_mul)
		DayLoopConfig.PhaseType.DUSK:
			_apply_phase_profile(dusk_move_speed_mul, dusk_attack_speed_mul, dusk_patrol_distance_mul, dusk_perception_mul)
		DayLoopConfig.PhaseType.NIGHT:
			_apply_phase_profile(night_move_speed_mul, night_attack_speed_mul, night_patrol_distance_mul, night_perception_mul)
		_:
			_apply_phase_profile(1.0, 1.0, 1.0, 1.0)

# 应用具体的昼夜倍率并重算当前状态属性与感知范围缩放
func _apply_phase_profile(move_mul: float, attack_mul: float, patrol_mul: float, perception_mul: float) -> void:
	_phase_move_speed_mul = max(0.1, move_mul)
	_phase_attack_speed_mul = max(0.1, attack_mul)
	_phase_patrol_distance_mul = max(0.1, patrol_mul)
	_phase_perception_mul = max(0.1, perception_mul)

	charge_duration = _base_charge_duration * _phase_attack_speed_mul
	patrol_radius = _base_patrol_radius * _phase_patrol_distance_mul
	patrol_wander_min = _base_patrol_wander_min * _phase_patrol_distance_mul
	patrol_wander_max = _base_patrol_wander_max * _phase_patrol_distance_mul

	if patrol_wander_min > patrol_wander_max:
		var t = patrol_wander_min # 缓冲变量用于交换大小值
		patrol_wander_min = patrol_wander_max
		patrol_wander_max = t
		
	if detection_Area:
		detection_Area.scale = _base_detection_scale * _phase_perception_mul

# 确保动态加载并实例化敌人的听觉组件节点
func _ensure_ear_node() -> void:
	if get_node_or_null("EnemyEar"):
		return
	if not ResourceLoader.exists(EAR_SCENE_PATH):
		push_warning("未找到 EnemyEar 场景: " + EAR_SCENE_PATH)
		return
	var ear_scene := load(EAR_SCENE_PATH) as PackedScene
	if not ear_scene:
		push_warning("EnemyEar 场景加载失败: " + EAR_SCENE_PATH)
		return
	var ear_instance = ear_scene.instantiate()
	if ear_instance:
		ear_instance.name = "EnemyEar"
		add_child(ear_instance)
		if ear_instance is EnemyEar:
			ear_instance.enemy = self

# 初始化头顶的各种状态提示 UI (警觉/脱锁等)
func _setup_alert_label() -> void:
	if not alert_label:
		return
	alert_label.visible = false
	alert_label.text = ""
	alert_label.modulate = alert_text_color

# 实时更新敌人的头顶标示符，以表现当前的 AI 锁定和警觉状态
func _update_alert_indicator(delta: float) -> void:
	if not alert_label:
		return
	if is_dead:
		alert_label.visible = false
		_alert_lost_lock_timer = 0.0
		_was_aggro_active = false
		return
	
	if _was_aggro_active and not is_aggro_active:
		_alert_lost_lock_timer = alert_lost_lock_duration
	_was_aggro_active = is_aggro_active
	
	if _alert_lost_lock_timer > 0.0:
		_alert_lost_lock_timer = max(0.0, _alert_lost_lock_timer - delta)
	
	if is_aggro_active:
		alert_label.text = "!"
		alert_label.visible = true
	elif is_noise_investigating:
		alert_label.text = "?"
		alert_label.visible = true
	elif _alert_lost_lock_timer > 0.0:
		alert_label.text = "..."
		alert_label.visible = true
	else:
		alert_label.visible = false

# 接收从 EnemyEar 或其他系统传来的噪音信号
func receive_noise_signal(source_pos: Vector2, noise_value: float) -> void:
	if is_dead or is_stunned:
		return
	if noise_value <= 0.0:
		return
	# 无论当前是否索敌，都先刷新“最后发声点”，避免脱锁后追旧点
	noise_investigate_target = source_pos
	if is_aggro_active or is_returning:
		return
	is_noise_investigating = true
	set_navigation_target(noise_investigate_target)
	if state_machine and state_machine.current_node_state_name.to_lower() != "patrol":
		state_machine.transition_to("Patrol")

# 返回当前是否正在调查噪音
func has_noise_investigation() -> bool:
	return is_noise_investigating

# 返回最后记录的噪音发声点坐标
func get_last_sound_point() -> Vector2:
	return noise_investigate_target

# 返回当前需要调查的具体坐标目标
func get_noise_investigation_target() -> Vector2:
	return get_last_sound_point()

# 清除当前记录的噪音调查状态与坐标
func clear_noise_investigation() -> void:
	is_noise_investigating = false
	noise_investigate_target = Vector2.ZERO
#endregion

#region 10. 物理受力与状态控制
# 计算并合并环境斥力，处理同类推挤与动态滑开逻辑
func _calculate_environment_forces() -> Vector2:
	if not detection_Area: return Vector2.ZERO
	
	var neighbors = detection_Area.get_overlapping_bodies() # 当前感知区域内的实体数组
	var total_separation = Vector2.ZERO # 累计的分离力
	var total_push = Vector2.ZERO # 累计的推挤力
	var sep_count = 0 # 参与分离计算的实体计数
	var min_separation_dist = 20.0 # 最小触发分离受力的距离边界
	
	var is_moving = velocity.length_squared() > 100.0 # 当前是否处于移动状态
	var move_dir = velocity.normalized() # 当前运动方向向量
	
	for body in neighbors:
		if body == self: continue
		
		var diff = global_position - body.global_position # 自身与环境实体的距离差向量
		var dist_sq = diff.length_squared() # 距离的平方值
		var dist = sqrt(dist_sq) # 实际相对距离
		
		if body is Enemy:
			var force = Vector2.ZERO # 临时斥力向量
			if dist < min_separation_dist:
				var effective_dist = max(0.1, dist) # 防除零的安全距离
				var strength = 1.0 - (effective_dist / min_separation_dist) # 距离权重衰减系数
				force = (diff / effective_dist) * strength * 5.0
			elif dist < 35.0:
				force = (diff / dist) * 0.5
			
			if force != Vector2.ZERO:
				if is_moving:
					var dot_prod = force.dot(move_dir) # 斥力与移动方向的点积结果
					if dot_prod < 0:
						force -= move_dir * dot_prod 
				total_separation += force
				sep_count += 1
				
		elif body is CharacterBase and body.character_type == CharacterType.PLAYER:
			var threshold_sq = push_threshold * push_threshold # 推挤检测半径的平方值
			if dist_sq < threshold_sq and dist_sq > 0.1:
				var weight = 1.0 - (dist / push_threshold) # 推挤力权重系数
				total_push += (diff / dist) * push_force * weight

	var final_force = Vector2.ZERO # 汇总后的最终计算环境力
	if sep_count > 0:
		final_force = total_separation.normalized() * separation_force
		
	return final_force + total_push

# 强制重置敌人的整体物理及行为状态
func reset_status() -> void:
	super.reset_status()
	force_stop_aggro()
	is_returning = false
	clear_noise_investigation()
	_reset_navigation_recovery_state()
#endregion
