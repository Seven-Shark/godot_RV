extends Node

## 全局大管家 (GameManager - Autoload)
## 职责：管理跨场景的全局数据、处理核心的场景切换逻辑与黑屏过渡。

signal scene_ready_to_reveal ## 新场景布置完毕，请求大管家撤掉黑幕的信号

#region 1. 场景路径配置
# ⚠️ 请确认这里的路径与你项目实际路径大小写完全一致
const HOME_SCENE_PATH = "uid://do3f2oap0omos"
const SURVIVAL_SCENE_PATH = "uid://jpvsf2xi82bq"
#endregion

#region 2. 全局游戏数据与节点
var current_day: int = 1 ## 当前生存的天数/轮次
var pending_ers_objects: Array[PackedScene] = [] ## 准备带入探险地图的物件

# ==========================================
# [新增] 记录当前选择的地图规则（掉血速率）
var current_map_decay_rate: float = 15.0 
# ==========================================

var transition_rect: ColorRect ## 动态生成的全屏黑幕
var is_transitioning: bool = false ## 防止狂点重复切场景
#endregion

#region 3. 生命周期
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_transition_ui()
	print(">>> [GameManager] 全局大管家已就绪。当前天数: ", current_day)

func _setup_transition_ui() -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100 
	add_child(canvas_layer)
	
	transition_rect = ColorRect.new()
	transition_rect.color = Color.BLACK
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.modulate.a = 0.0
	
	canvas_layer.add_child(transition_rect)
#endregion

#region 4. 场景切换与流程控制

## [核心流程] 开始探险
## [修复] 增加了 map_decay_rate 参数，现在大管家可以接住传送门传来的掉血设定了！
func goto_survival_scene(purchased_items: Array[PackedScene] = [], map_decay_rate: float = 2.0) -> void:
	if is_transitioning: return
	print(">>> [GameManager] 准备出发！记录 ERS 物品与地图规则，前往探险...")
	
	pending_ers_objects = purchased_items
	current_map_decay_rate = map_decay_rate # 存下当前地图的掉血率
	
	_fade_and_change_scene(SURVIVAL_SCENE_PATH)

## [核心流程] 返回家园
func goto_home_scene(is_victory: bool = false) -> void:
	if is_transitioning: return
	if is_victory:
		print(">>> [GameManager] 探险成功！正在返回家园...")
		current_day += 1 
	else:
		print(">>> [GameManager] 探险失败(阵亡)。正在返回家园...")
	
	pending_ers_objects.clear()
	_fade_and_change_scene(HOME_SCENE_PATH)

## [私有协程] 完美的异步加载与黑屏过渡
func _fade_and_change_scene(scene_uid: String) -> void:
	is_transitioning = true
	transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	get_tree().paused = true
	
	var tween_in = create_tween()
	tween_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_in.tween_property(transition_rect, "modulate:a", 1.0, 0.4)
	await tween_in.finished
	
	var scene = load(scene_uid)
	if scene:
		var err = get_tree().change_scene_to_packed(scene)
		if err != OK:
			push_error(">>> [GameManager] 无法加载场景: " + scene_uid)
	else:
		push_error(">>> [GameManager] 无法加载场景资源: " + scene_uid)
	
	await self.scene_ready_to_reveal
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var tween_out = create_tween()
	tween_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_out.tween_property(transition_rect, "modulate:a", 0.0, 0.4)
	await tween_out.finished
	
	get_tree().paused = false
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
#endregion
