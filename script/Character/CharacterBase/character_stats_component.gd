extends StatsComponent
class_name CharacterStatsComponent

## 角色属性组件 (子类)
## 适用对象：玩家、敌人 (CharacterBase)
## 功能：继承基础血量功能，并扩展耐力系统、移动速度计算、负重系统

#region 信号定义
signal stamina_changed(current, max) ## 耐力值发生变化时触发
#endregion

#region 2. 耐力值配置
@export_group("Stamina Stats")
@export var enable_stamina: bool = true          ## 开关：是否启用耐力系统
@export var max_stamina: float = 100.0           ## 最大耐力值上限
@export var stamina_regen: float = 10.0          ## 每秒自动恢复的耐力值
@export var stamina_regen_delay: float = 1.0     ## 消耗耐力后，暂停恢复的延迟时间(秒)
@export var sprint_cost_per_sec: float = 20.0    ## 冲刺时每秒消耗的耐力值
#endregion

#region 3. 移动与负重配置
@export_group("Movement & Weight")
@export var base_walk_speed: float = 150.0       ## 基础移动速度 (走路)
@export var sprint_speed: float = 250.0          ## 冲刺移动速度 (跑步)
@export var sprint_cd: float = 3.0               ## 冲刺疲劳后的冷却时间(秒)
@export var max_weight: float = 50.0             ## 最大负重上限
@export var weight_slowdown_factor: float = 0.5  ## 满负重时的减速比例 (0.5 = 减速50%)
#endregion

#region 内部状态变量
var current_stamina: float = 0.0                 ## [内部] 当前耐力值
var current_weight: float = 0.0                  ## [内部] 当前负重
var regen_delay_timer: float = 0.0               ## [内部] 耐力恢复延迟计时器
var sprint_timer: float = 0.0                    ## [内部] 冲刺冷却计时器
var can_sprint: bool = true                      ## [内部] 是否允许冲刺标志位
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

#region 内部逻辑处理
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

# 处理冲刺冷却倒计时
func _handle_cooldowns(delta: float):
	if not can_sprint:
		sprint_timer -= delta
		if sprint_timer <= 0:
			can_sprint = true
			# 可以在这里增加信号通知 UI 冲刺就绪
#endregion

#region 公共接口 (Public API)
## [核心] 尝试消耗耐力，成功返回 true，失败(耐力不足)则触发冷却并返回 false
func try_consume_stamina(amount: float) -> bool:
	if not enable_stamina: return true
	
	if current_stamina >= amount:
		current_stamina -= amount
		stamina_changed.emit(current_stamina, max_stamina)
		regen_delay_timer = stamina_regen_delay # 重置恢复延迟
		return true
	
	# 耐力不足，触发强制冷却
	start_sprint_cooldown()
	return false

## 手动触发冲刺冷却 (通常用于耐力耗尽或主动停止冲刺时)
func start_sprint_cooldown():
	if can_sprint:
		can_sprint = false
		sprint_timer = sprint_cd

## [核心] 计算最终移动速度 (综合冲刺状态、耐力消耗和负重惩罚)
## 注意：必须传入 delta 以便准确计算每帧的耐力消耗
func get_final_speed(is_sprinting_input: bool, delta: float = 0.016) -> float:
	var target_speed = base_walk_speed
	
	# --- 1. 冲刺逻辑处理 ---
	if is_sprinting_input and can_sprint and enable_stamina:
		var cost = sprint_cost_per_sec * delta # 计算当前帧消耗量
		if try_consume_stamina(cost):
			target_speed = sprint_speed
		else:
			target_speed = base_walk_speed # 扣除失败，退回走路速度
	
	# --- 2. 负重逻辑处理 ---
	if current_weight > 0:
		# 计算负重比率 (0.0 ~ 1.0)
		var weight_ratio = clamp(current_weight / max_weight, 0.0, 1.0)
		# 计算减速乘数 (例如负重满时，速度乘以 0.5)
		var penalty_multiplier = 1.0 - (weight_ratio * weight_slowdown_factor)
		target_speed *= penalty_multiplier
		
	return target_speed

## 更新当前负重数值
func update_weight(amount: float):
	current_weight = clamp(current_weight + amount, 0, 9999)
#endregion
