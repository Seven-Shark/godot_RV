extends StatsComponent
class_name CharacterStatsComponent

## 角色属性组件 (子类)
## 适用对象：玩家、敌人 (CharacterBase)
## 功能：继承基础血量功能，并扩展耐力系统、移动速度计算、负重系统、冲刺数据与逻辑管理

#region 信号定义
signal stamina_changed(current, max) ## 耐力值发生变化时触发
#endregion

#region 1. 耐力值配置
@export_group("Stamina Stats")
@export var enable_stamina: bool = true          ## 开关：是否启用耐力系统
@export var max_stamina: float = 100.0           ## 最大耐力值上限
@export var stamina_regen: float = 10.0          ## 每秒自动恢复的耐力值
@export var stamina_regen_delay: float = 1.0     ## 消耗耐力后，暂停恢复的延迟时间(秒)
@export var sprint_cost_per_sec: float = 20.0    ## 持续跑步(Sprint)时每秒消耗的耐力值
#endregion

#region 2. 移动与负重配置
@export_group("Movement & Weight")
@export var base_walk_speed: float = 150.0       ## 基础移动速度 (走路)
@export var sprint_speed: float = 250.0          ## 跑步移动速度 (按住Shift)
@export var sprint_cd: float = 3.0               ## 跑步疲劳后的冷却时间(秒)
@export var max_weight: float = 50.0             ## 最大负重上限
@export var weight_slowdown_factor: float = 0.5  ## 满负重时的减速比例 (0.5 = 减速50%)
#endregion

#region 3. 冲刺技能配置 (Dash Ability)
@export_group("Dash Ability")
@export var dash_impulse: float = 1000.0      ## 冲刺瞬间爆发速度
@export var dash_duration: float = 0.2        ## 冲刺持续时间 (秒)
@export var dash_cooldown: float = 1.0        ## 冲刺冷却时间 (秒)
@export var dash_stamina_cost: float = 15.0   ## 每次冲刺消耗的固定耐力值
#endregion

#region 内部状态变量
var current_stamina: float = 0.0                 ## [内部] 当前耐力值
var current_weight: float = 0.0                  ## [内部] 当前负重
var regen_delay_timer: float = 0.0               ## [内部] 耐力恢复延迟计时器

# --- 跑步(Sprint)状态 ---
var sprint_timer: float = 0.0                    ## [内部] 跑步冷却计时器
var can_sprint: bool = true                      ## [内部] 是否允许跑步标志位

# --- 冲刺(Dash)状态 ---
var _is_dash_cooling_down: bool = false          ## [内部] 是否处于冲刺冷却中
var _current_dash_time_left: float = 0.0         ## [内部] 当前冲刺剩余时间 (物理倒计时)
#endregion

#region 生命周期重写
# 重写初始化：先调用父类初始化血量，再初始化耐力
func _initialize_stats():
	super._initialize_stats() # 必须调用父类方法以初始化血量
	current_stamina = max_stamina
	stamina_changed.emit(current_stamina, max_stamina)

# 重写每帧处理：先处理父类(回血)，再处理子类(回耐力、冷却)
func _process(delta: float) -> void:
	super._process(delta) # 必须调用父类方法以处理回血和死亡检查
	
	if not is_dead:
		_handle_stamina_regen(delta)
		_handle_cooldowns(delta)
#endregion

#region 内部逻辑处理 (Regen & Cooldown)
# 处理耐力自动恢复逻辑 (包含延迟判断)
func _handle_stamina_regen(delta: float):
	if not enable_stamina: return
	
	# 如果处于恢复延迟期，只扣时间不回蓝
	if regen_delay_timer > 0:
		regen_delay_timer -= delta
		return
	
	# 执行恢复
	if current_stamina < max_stamina:
		current_stamina = min(current_stamina + stamina_regen * delta, max_stamina)
		stamina_changed.emit(current_stamina, max_stamina)

# 处理跑步冷却倒计时 (Sprint Cooldown)
func _handle_cooldowns(delta: float):
	if not can_sprint:
		sprint_timer -= delta
		if sprint_timer <= 0:
			can_sprint = true
#endregion

#region 公共接口 - 基础能力 (Basic API)

## [核心] 尝试消耗耐力
## @return: 成功返回 true，失败(耐力不足)则触发跑步冷却并返回 false
func try_consume_stamina(amount: float) -> bool:
	if not enable_stamina: return true
	
	if current_stamina >= amount:
		current_stamina -= amount
		stamina_changed.emit(current_stamina, max_stamina)
		regen_delay_timer = stamina_regen_delay # 重置恢复延迟
		return true
	
	# 耐力不足，触发强制跑步冷却
	start_sprint_cooldown()
	return false

## 手动触发跑步冷却 (Sprint Cooldown)
func start_sprint_cooldown():
	if can_sprint:
		can_sprint = false
		sprint_timer = sprint_cd

## [核心] 计算最终移动速度 (综合跑步状态、耐力消耗和负重惩罚)
func get_final_speed(is_sprinting_input: bool, delta: float = 0.016) -> float:
	var target_speed = base_walk_speed
	
	# --- 1. 跑步逻辑处理 ---
	if is_sprinting_input and can_sprint and enable_stamina:
		var cost = sprint_cost_per_sec * delta # 计算当前帧消耗量
		if try_consume_stamina(cost):
			target_speed = sprint_speed
		else:
			target_speed = base_walk_speed # 扣除失败，退回走路速度
	
	# --- 2. 负重逻辑处理 ---
	if current_weight > 0:
		var weight_ratio = clamp(current_weight / max_weight, 0.0, 1.0)
		var penalty_multiplier = 1.0 - (weight_ratio * weight_slowdown_factor)
		target_speed *= penalty_multiplier
		
	return target_speed

## 更新当前负重数值
func update_weight(amount: float):
	current_weight = clamp(current_weight + amount, 0, 9999)

## 重置所有属性 (复活/重生时调用)
func reset_stats() -> void:
	current_health = max_health
	current_stamina = max_stamina
	is_dead = false
	
	# 重置状态位
	_is_dash_cooling_down = false
	can_sprint = true
	_current_dash_time_left = 0.0
	
	# 通知外部 UI 更新
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)
	
	print(">>> [StatsComponent] 属性已重置")
#endregion

#region 公共接口 - 冲刺逻辑 (Dash Logic)

## [核心] 1. 查询冲刺是否就绪 (只检查，不消耗)
## 用于状态机(Idle/Walk)在切换前判断，防止进入死循环导致鬼畜
func can_use_dash() -> bool:
	# 检查冷却
	if _is_dash_cooling_down:
		return false
	# 检查耐力
	if current_stamina < dash_stamina_cost:
		return false
	return true

## [核心] 2. 检查并消耗冲刺资源 (用于 Dash 状态进入时)
## 如果可以，则扣除耐力并进入冷却，返回 true；否则返回 false
func check_and_consume_dash() -> bool:
	if not can_use_dash():
		return false
	
	# 扣除耐力
	try_consume_stamina(dash_stamina_cost)
		
	# 触发冷却逻辑 (异步)
	_start_dash_cooldown_timer()
	return true

## [核心] 3. 计算冲刺速度向量，并初始化计时器
## @param input_dir: 玩家输入的移动方向
## @param facing_dir: 玩家当前的朝向 (用于兜底)
## @return: 计算好的最终速度向量
func calculate_dash_velocity(input_dir: Vector2, facing_dir: Vector2) -> Vector2:
	# 确定方向
	var final_dir = input_dir.normalized()
	if final_dir == Vector2.ZERO:
		final_dir = facing_dir.normalized()
		# 兜底：如果连朝向都没有，默认向右
		if final_dir == Vector2.ZERO: final_dir = Vector2.RIGHT
	
	# 设置计时器 (开始冲刺)
	_current_dash_time_left = dash_duration
	
	# 返回速度
	return final_dir * dash_impulse

## [核心] 4. 处理冲刺物理计时 (Tick)
## 在状态机的 physics_process 中调用
## @return: 如果冲刺时间结束返回 true (建议切换状态)，否则返回 false
func tick_dash_timer(delta: float) -> bool:
	if _current_dash_time_left > 0:
		_current_dash_time_left -= delta
		if _current_dash_time_left <= 0:
			return true # 时间到
		return false # 还在冲
	return true # 早就结束了

## [辅助] 查询冲刺是否结束
func is_dash_finished() -> bool:
	return _current_dash_time_left <= 0.0

## [辅助] 强制停止冲刺计时 (用于被打断/退出状态时的清理)
func force_stop_dash_timer() -> void:
	_current_dash_time_left = 0.0

## [内部] 处理冲刺冷却计时
func _start_dash_cooldown_timer() -> void:
	_is_dash_cooling_down = true
	# 使用 SceneTreeTimer 进行一次性倒计时
	await get_tree().create_timer(dash_cooldown).timeout
	_is_dash_cooling_down = false
#endregion
