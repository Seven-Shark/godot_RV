extends Node
class_name StatsComponent

## 属性组件 (StatsComponent)
##
## 负责管理角色的核心数值，包括：
## 1. 生命值 (Health) - 受伤、回血、死亡
## 2. 耐力值 (Stamina) - 消耗、恢复、动作限制
## 3. 移动与负重 (Movement & Weight) - 速度计算、负重惩罚

#region 信号定义
signal health_changed(current, max)   ## 生命值变化时触发
signal stamina_changed(current, max)  ## 耐力值变化时触发
signal died                           ## 生命值归零时触发
#endregion

#region 1. 生命值配置
@export_group("Health Stats")
@export var max_health: float = 100.0   ## 最大生命值上限
@export var health_regen: float = 0.0   ## 每秒自动恢复的生命值量
@export var healthbar: ProgressBar      ## (可选) 绑定的血条 UI 节点，用于自动更新显示
#endregion

#region 2. 耐力值配置
@export_group("Stamina Stats")
@export var enable_stamina: bool = true         ## 开关：是否启用耐力系统 (false 表示无限耐力)
@export var max_stamina: float = 100.0          ## 最大耐力值上限
@export var stamina_regen: float = 10.0         ## 每秒自动恢复的耐力值量
@export var stamina_regen_delay: float = 1.0    ## 消耗耐力后，暂停恢复的延迟时间 (秒)
#endregion

#region 3. 移动与负重配置
@export_group("Movement & Weight")
@export var base_walk_speed: float = 150.0      ## 基础移动速度 (走路)
@export var sprint_speed: float = 250.0         ## 冲刺时的移动速度 (跑步)
@export var sprint_cd: float = 3.0              ## 冲刺功能的冷却时间 (秒)
@export var max_weight: float = 50.0            ## 最大负重上限
@export var weight_slowdown_factor: float = 0.5 ## 满负重时的减速比例 (例如 0.5 = 减速50%)
#endregion

#region 内部状态变量
var current_health: float          ## 当前生命值
var current_stamina: float         ## 当前耐力值
var current_weight: float = 0.0    ## 当前负重
var regen_delay_timer: float = 0.0 ## 耐力恢复延迟计时器
var sprint_timer: float = 0.0      ## 冲刺冷却计时器
var can_sprint: bool = true        ## 是否可以冲刺
#endregion

#region 生命周期
func _ready() -> void:
	# 初始化数值
	current_health = max_health
	current_stamina = max_stamina
	
	# 初始广播一下UI
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)

func _process(delta: float) -> void:
	_handle_health_regen(delta)
	_handle_stamina_regen(delta)
	_handle_cooldowns(delta)
#endregion

#region 内部逻辑处理
# 处理生命恢复
func _handle_health_regen(delta: float):
	if current_health < max_health and current_health > 0 and health_regen > 0:
		current_health = min(current_health + health_regen * delta, max_health)
		health_changed.emit(current_health, max_health)

# 处理耐力恢复（包含延迟逻辑）
func _handle_stamina_regen(delta: float):
	if not enable_stamina: return
	
	# 如果正在冷却（比如刚跑完），倒计时
	if regen_delay_timer > 0:
		regen_delay_timer -= delta
		return
	
	# 开始恢复
	if current_stamina < max_stamina:
		current_stamina = min(current_stamina + stamina_regen * delta, max_stamina)
		stamina_changed.emit(current_stamina, max_stamina)

# 处理冲刺冷却
func _handle_cooldowns(delta: float):
	if not can_sprint:
		sprint_timer -= delta
		if sprint_timer <= 0:
			can_sprint = true
			# 这里可以发个信号告诉UI冲刺好了
#endregion

#region 公共接口 (Public API)

## 1. 承受伤害
## [param amount]: 扣除的血量
func take_damage(amount: float):
	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		current_health = 0
		died.emit()

## 2. 尝试消耗耐力
## [param amount]: 需要消耗的耐力值
## 返回: true 表示消耗成功，false 表示耐力不足
func try_consume_stamina(amount: float) -> bool:
	if not enable_stamina: return true # 如果没开耐力系统，默认随便用
	
	if current_stamina >= amount:
		current_stamina -= amount
		stamina_changed.emit(current_stamina, max_stamina)
		regen_delay_timer = stamina_regen_delay # 重置回复等待时间
		return true
	return false

## 3. 触发冲刺冷却 (通常在耐力耗尽或主动停止冲刺时调用)
func start_sprint_cooldown():
	can_sprint = false
	sprint_timer = sprint_cd

## 4. 获取最终移动速度
## 根据是否冲刺、耐力是否足够以及当前负重计算最终速度
## [param is_sprinting]: 角色是否发出了冲刺指令
func get_final_speed(is_sprinting: bool) -> float:
	var target_speed = base_walk_speed
	
	# 检查冲刺条件：按下冲刺键 + 没在冷却 + 耐力足够(每帧消耗0.5测试)
	if is_sprinting and can_sprint and try_consume_stamina(0.5): 
		target_speed = sprint_speed
	
	# 计算负重惩罚
	# 负重比例 = 当前负重 / 最大负重
	# 速度乘数 = 1.0 - (负重比例 * 减速系数)
	if current_weight > 0:
		var weight_ratio = clamp(current_weight / max_weight, 0.0, 1.0)
		var penalty_multiplier = 1.0 - (weight_ratio * weight_slowdown_factor)
		target_speed *= penalty_multiplier
		
	return target_speed

## 5. 更新负重
## [param amount]: 增加或减少的重量 (正数为加，负数为减)
func update_weight(amount: float):
	current_weight = clamp(current_weight + amount, 0, 9999)
	# 可以在这里做超重完全走不动的逻辑
#endregion
