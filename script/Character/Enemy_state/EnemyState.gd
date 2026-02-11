class_name EnemyState
extends NodeState

## -------------------------------------------------------
## 敌人状态基类 (中间层)
## 职责：
## 1. 自动获取 enemy 和 anim 引用
## 2. 提供 create_safe_tween()，在状态退出时自动销毁 Tween
## 3. 标准化 enter/exit 接口
## -------------------------------------------------------

# 自动获取引用的变量 (子类直接用)
var enemy: Enemy
var anim: AnimatedSprite2D

# 垃圾回收列表
var _active_tweens: Array[Tween] = []

# --- 重写通用模板的生命周期 (Template Method) ---

func _on_enter() -> void:
	# 1. 自动查找引用
	if not enemy:
		enemy = get_parent().get_parent() as Enemy
		anim = enemy.sprite
	
	# 2. 调用子类逻辑
	enter()

func _on_exit() -> void:
	# 1. [核心安全机制] 自动清理所有注册的 Tween
	# 防止攻击状态被打断后，红框还在变长或触发伤害
	for t in _active_tweens:
		if t and t.is_valid():
			t.kill()
	_active_tweens.clear()
	
	# 2. 调用子类清理
	exit()

# --- 供子类重写的虚函数 ---
func enter() -> void: pass
func exit() -> void: pass

# --- 安全工具 ---
## 创建一个随状态结束而自动销毁的 Tween
func create_safe_tween() -> Tween:
	var t = create_tween()
	_active_tweens.append(t)
	t.finished.connect(func(): _active_tweens.erase(t))
	return t
