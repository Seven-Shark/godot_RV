extends Node
# 注意：全局单例脚本通常不需要写 class_name，因为我们会在引擎里直接命名它。

## 全局大管家 (GameManager - Autoload)
## 职责：管理跨场景的全局数据（天数、带入副本的物品）、处理核心的场景切换逻辑。
## 说明：请务必在 Godot 编辑器的“项目 -> 项目设置 -> 自动加载(Autoload)”中将此脚本添加为 GameManager。

#region 1. 场景路径配置
# ⚠️ 请根据你项目的实际文件结构，修改这两个字符串的路径
const HOME_SCENE_PATH = "res://Scenes/HomeScene.tscn" 
const SURVIVAL_SCENE_PATH = "res://Scenes/SurvivalScene.tscn"
#endregion

#region 2. 全局游戏数据
var current_day: int = 1 ## 当前生存的天数/轮次
var pending_ers_objects: Array[PackedScene] = [] ## 玩家在 ERS 界面购买/选择，准备带入探险地图的物件
#endregion

#region 3. 生命周期
## [初始化] GameManager 随游戏启动而加载，常驻内存
func _ready() -> void:
	# 确保在单例加载时，游戏是不暂停的
	process_mode = Node.PROCESS_MODE_ALWAYS
	print(">>> [GameManager] 全局大管家已就绪。当前天数: ", current_day)
#endregion

#region 4. 场景切换与流程控制

## [核心流程] 开始探险 (由家园的 ERS 界面选完物品后调用)
## 参数 purchased_items: 玩家购买或选择的物品数组
func goto_survival_scene(purchased_items: Array[PackedScene] = []) -> void:
	print(">>> [GameManager] 准备出发！记录 ERS 物品并前往探险地图...")
	
	# 1. 记录要带入副本的数据（以便 LevelManager 加载时读取）
	pending_ers_objects = purchased_items
	
	# 2. 切换到探险场景
	var err = get_tree().change_scene_to_file(SURVIVAL_SCENE_PATH)
	if err != OK:
		push_error(">>> [GameManager] 无法加载探险场景，请检查路径: " + SURVIVAL_SCENE_PATH)
	else:
		# 确保切场景时游戏时间流动正常
		get_tree().paused = false

## [核心流程] 返回家园 (由探险地图的 GameDirector 结算或死亡时调用)
## 参数 is_victory: 标记是胜利通关还是阵亡回城 (留作后续扩展统计或扣除掉落物)
func goto_home_scene(is_victory: bool = false) -> void:
	if is_victory:
		print(">>> [GameManager] 探险成功！正在返回家园...")
		current_day += 1 # 胜利才算活过了一天（可根据你的设计修改逻辑）
	else:
		print(">>> [GameManager] 探险失败(阵亡)。正在返回家园...")
		# 阵亡也许不加天数，或者重置某些数据，可在此处扩展
	
	# 1. 清空上一轮的带入物品，防止重复生成
	pending_ers_objects.clear()
	
	# 2. 切换回首家园场景
	var err = get_tree().change_scene_to_file(HOME_SCENE_PATH)
	if err != OK:
		push_error(">>> [GameManager] 无法加载家园场景，请检查路径: " + HOME_SCENE_PATH)
	else:
		# ⚠️ 关键修复：死亡时通常 get_tree().paused 会被设为 true。
		# 切回主城必须强制恢复时间流动，否则家园里的玩家也会动不了！
		get_tree().paused = false

#endregion
