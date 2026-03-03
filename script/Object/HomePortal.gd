extends Area2D

## 家園傳送門 (HomePortal)
## 職責：檢測玩家靠近，顯示交互提示，自動關聯 GameHUD 中的 ERS 界面，並開啟探險流程。

#region 1. 引用配置
var ers_manager: Node = null ## [動態獲取] ERS 商店實例
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
	
	# 3. 延遲一幀尋找 ERS 節點，確保 GameHUD 已加載
	call_deferred("_find_ers_from_hud")

## [內部邏輯] 從場景樹中動態尋找 GameHUD 及其內部的 ERS 插件
func _find_ers_from_hud() -> void:
	# 先嘗試直接尋找名為 GameHUD 的節點（或者是你 HUD 腳本所在的類名）
	var hud = get_tree().current_scene.find_child("GameHUD", true, false)
	
	if hud:
		# 檢查 GameHUD 腳本中是否定義了 ers_manager 變量
		if "ers_manager" in hud and hud.ers_manager:
			ers_manager = hud.ers_manager
		else:
			# 如果 HUD 沒暴露變量，則在 HUD 子節點中深層搜索 ERS_Manager
			ers_manager = hud.find_child("ERS_Manager", true, false)
	
	# 最後檢查：如果還是沒找到，嘗試在整個當前場景全局搜索
	if not ers_manager:
		ers_manager = get_tree().current_scene.find_child("ERS_Manager", true, false)
	
	# 成功關聯後的信號連接
	if ers_manager:
		print(">>> [Portal] 成功關聯 ERS_Manager")
		if ers_manager.has_signal("items_confirmed"):
			ers_manager.items_confirmed.connect(_on_ers_items_confirmed)
	else:
		push_warning(">>> [Portal] 警告：未能找到 ERS_Manager，請檢查 GameHUD 結構")

#endregion

#region 4. 交互邏輯
func _input(event: InputEvent) -> void:
	# 只有當玩家在範圍內、按下交互鍵、且 ERS 已經被找到時才觸發
	if is_player_in_range and GameInputEvents.is_interact_event(event):
		if ers_manager and ers_manager.has_method("open_ers_shop"):
			_toggle_interaction_ui(false) # 隱藏提示文字避免穿模
			ers_manager.open_ers_shop(true)

## [信號回調] ERS 確認後，將物品和地圖規則一起交給 GameManager
func _on_ers_items_confirmed(items: Array[PackedScene]) -> void:
	print(">>> [Portal] 收到確認，準備前往探險... 掉血率: ", target_map_decay_rate)
	GameManager.goto_survival_scene(items, target_map_decay_rate)
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
