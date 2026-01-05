extends Node
class_name StatsComponent

# 定义信号，方便UI（比如血条）监听变化，不用每帧去读取
signal health_changed(current, max)
signal stamina_changed(current, max)
signal died

# 使用 export_group 让编辑器面板更整洁
# --------------------------------------------------------
# 1. 生命值系统
# --------------------------------------------------------
@export_group("Health Stats")
@export var max_health: float = 100.0
@export var health_regen: float = 0.0 # 每秒回血量
@export var healthbar : ProgressBar #血条显示
var current_health: float

# --------------------------------------------------------
# 2. 耐力系统
# --------------------------------------------------------
@export_group("Stamina Stats")
@export var enable_stamina: bool = true # 开关：有些敌人可能不需要耐力
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 10.0 # 每秒回耐量
@export var stamina_regen_delay: float = 1.0 # 消耗耐力后，多久开始回复（秒）
var current_stamina: float
var regen_delay_timer: float = 0.0 # 内部计时器

# --------------------------------------------------------
# 3. 移动与负重系统
# --------------------------------------------------------
@export_group("Movement & Weight")
@export var base_walk_speed: float = 150.0 #基础移动速度
@export var sprint_speed: float = 250.0
@export var sprint_cd: float = 3.0 # 冲刺冷却时间
@export var max_weight: float = 50.0
@export var weight_slowdown_factor: float = 0.5 # 满负重时减少多少速度 (0.5 = 减速50%)

var current_weight: float = 0.0
var can_sprint: bool = true
var sprint_timer: float = 0.0


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
	
# --- 逻辑处理区域 ---

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

# --- 公共接口（给 Player/Enemy 调用的） ---

# 1. 扣血
func take_damage(amount: float):
	current_health -= amount
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		current_health = 0
		died.emit()

# 2. 消耗耐力 (返回 true 表示消耗成功，false 表示耐力不足)
func try_consume_stamina(amount: float) -> bool:
	if not enable_stamina: return true # 如果没开耐力系统，默认随便用
	
	if current_stamina >= amount:
		current_stamina -= amount
		stamina_changed.emit(current_stamina, max_stamina)
		regen_delay_timer = stamina_regen_delay # 重置回复等待时间
		return true
	return false

# 3. 触发冲刺冷却
func start_sprint_cooldown():
	can_sprint = false
	sprint_timer = sprint_cd

# 4. 获取当前计算负重后的最终移动速度
# is_sprinting: 角色是否想冲刺
func get_final_speed(is_sprinting: bool) -> float:
	var target_speed = base_walk_speed
	
	if is_sprinting and can_sprint and try_consume_stamina(0.5): # 假设冲刺每帧消耗一点点耐力，这里逻辑需结合_physics_process调整
		target_speed = sprint_speed
	
	# 计算负重惩罚
	# 负重比例 = 当前负重 / 最大负重
	# 速度乘数 = 1.0 - (负重比例 * 减速系数)
	if current_weight > 0:
		var weight_ratio = clamp(current_weight / max_weight, 0.0, 1.0)
		var penalty_multiplier = 1.0 - (weight_ratio * weight_slowdown_factor)
		target_speed *= penalty_multiplier
		
	return target_speed

# 增加/减少负重
func update_weight(amount: float):
	current_weight = clamp(current_weight + amount, 0, 9999)
	# 可以在这里做超重完全走不动的逻辑
	
