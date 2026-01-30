extends Node
class_name StatsComponent

## 基础属性组件 (基类)
## 适用对象：所有能被攻击的物体 (玩家、敌人、树、矿石)
## 功能：只负责核心血量管理、死亡判定和自动回血逻辑
## 注意：角色专有的耐力、移动速度等逻辑请参阅子类 CharacterStatsComponent

#region 信号定义
signal health_changed(current, max) ## 生命值发生变化时触发
signal died                         ## 生命值归零死亡时触发
#endregion

#region 1. 基础配置
@export_group("Health Stats")
@export var max_health: float = 100.0   ## 最大生命值上限
@export var health_regen: float = 0.0   ## 每秒自动恢复的生命值
@export var healthbar: ProgressBar      ## (可选) 绑定的血条 UI 节点，会自动更新数值
#endregion

#region 内部状态变量
var current_health: float = 0.0 ## [内部] 当前生命值
var is_dead: bool = false       ## [内部] 是否已死亡标记
#endregion

#region 生命周期
func _ready() -> void:
	_initialize_stats()

func _process(delta: float) -> void:
	if not is_dead:
		_handle_health_regen(delta)
#endregion

#region 内部逻辑处理
## [虚函数] 初始化数值，旨在被子类重写以添加更多初始化逻辑
func _initialize_stats() -> void:
	current_health = max_health
	_update_health_ui()
	health_changed.emit(current_health, max_health)

## 处理每秒自动回血逻辑
func _handle_health_regen(delta: float) -> void:
	if current_health < max_health and health_regen > 0:
		current_health = min(current_health + health_regen * delta, max_health)
		_update_health_ui()
		health_changed.emit(current_health, max_health)

## 更新绑定的血条 UI 显示
func _update_health_ui() -> void:
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = current_health
#endregion

#region 公共接口 (Public API)
## 承受伤害
## [param amount]: 扣除的血量值
func take_damage(amount: float) -> void:
	if is_dead: return
	
	current_health -= amount
	_update_health_ui()
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		current_health = 0
		is_dead = true
		died.emit()

## 治疗/恢复生命值
## [param amount]: 恢复的血量值
func heal(amount: float) -> void:
	if is_dead: return
	
	current_health = min(current_health + amount, max_health)
	_update_health_ui()
	health_changed.emit(current_health, max_health)
#endregion
