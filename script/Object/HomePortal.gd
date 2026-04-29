extends Area2D

## 家園傳送門 (HomePortal)
## 職責：檢測玩家靠近，顯示交互提示，並開啟探險流程。

#region 1. 引用配置
@export var interaction_label: Label ## 引用懸浮提示文字節點

@export_group("Portal Settings")
@export var target_map_decay_rate: float = 2.0 ## 傳給探險地圖的環境掉血速率
#endregion

#region 2. 狀態變數
var is_player_in_range: bool = false
#endregion

#region 3. 生命周期與初始化
func _ready() -> void:
	# 1. 基礎信號連接
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 2. 初始 UI 狀態
	if interaction_label:
		interaction_label.visible = false

#endregion

#region 4. 交互邏輯
func _input(event: InputEvent) -> void:
	# 玩家在範圍內按下交互鍵後，先打開 ERS 保底地圖選擇界面
	if is_player_in_range and GameInputEvents.is_interact_event(event):
		_toggle_interaction_ui(false) # 隱藏提示文字避免穿模
		var hud := get_tree().get_first_node_in_group("GameHUD") as GameHUD
		if hud and hud.open_ers_map_selection():
			print(">>> [Portal] 已打開 ERS 保底地圖選擇界面")
			return
		# 兜底：若 HUD 未就绪，回退到直接前往探險，避免流程卡死
		print(">>> [Portal] HUD 未就緒，回退直進探險。掉血率: ", target_map_decay_rate)
		GameManager.goto_survival_scene([], target_map_decay_rate)
#endregion

#region 5. 範圍檢測與視覺控制
## [私有方法] 統一控制交互 UI 的顯示（帶動畫效果）
func _toggle_interaction_ui(show: bool) -> void:
	if not interaction_label: return
	
	var tween = create_tween()
	if show:
		interaction_label.visible = true
		interaction_label.modulate.a = 0
		tween.tween_property(interaction_label, "modulate:a", 1.0, 0.2)
		tween.parallel().tween_property(interaction_label, "position:y", -100, 0.2).from(-60)
	else:
		tween.tween_property(interaction_label, "modulate:a", 0.0, 0.1)
		await tween.finished
		interaction_label.visible = false

func _on_body_entered(body: Node) -> void:
	if body is CharacterBase:
		is_player_in_range = true
		_toggle_interaction_ui(true)

func _on_body_exited(body: Node) -> void:
	if body is CharacterBase:
		is_player_in_range = false
		_toggle_interaction_ui(false)
#endregion
