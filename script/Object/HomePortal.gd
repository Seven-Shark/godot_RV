extends Area2D

## 家園傳送門 (HomePortal)
## 職責：檢測玩家靠近，顯示交互提示，並在範圍內按E開啟 ERS 界面。

#region 1. 引用配置
@export var ers_manager: Node ## ERS 商店實例
@export var interaction_label: Label ## [新增] 引用懸浮提示文字節點
#endregion

#region 2. 狀態變數
var is_player_in_range: bool = false
#endregion

#region 3. 生命周期與交互
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 確保初始狀態文字是隱藏的
	if interaction_label:
		interaction_label.visible = false
	
	if ers_manager and ers_manager.has_signal("items_confirmed"):
		ers_manager.items_confirmed.connect(_on_ers_items_confirmed)

func _input(event: InputEvent) -> void:
	if is_player_in_range and GameInputEvents.is_interact_event(event):
		if ers_manager:
			# 打開商店時可以順便把提示文字隱藏，避免遮擋 UI
			_toggle_interaction_ui(false)
			ers_manager.open_ers_shop(true)

func _on_ers_items_confirmed(items: Array[PackedScene]) -> void:
	GameManager.goto_survival_scene(items)
#endregion

#region 4. 範圍檢測與視覺控制
## [私有方法] 統一控制交互 UI 的顯示
func _toggle_interaction_ui(show: bool) -> void:
	if not interaction_label: return
	
	# 殺掉正在運行的動畫，防止衝突
	var tween = create_tween()
	
	if show:
		interaction_label.visible = true
		interaction_label.modulate.a = 0  # 從透明開始
		# 動畫：淡入 + 向上輕微位移
		tween.tween_property(interaction_label, "modulate:a", 1.0, 0.2)
		tween.parallel().tween_property(interaction_label, "position:y", -100, 0.2).from(-60)
	else:
		# 動畫：淡出
		tween.tween_property(interaction_label, "modulate:a", 0.0, 0.1)
		await tween.finished
		interaction_label.visible = false

func _on_body_entered(body: Node) -> void:
	if body is CharacterBase:
		is_player_in_range = true
		_toggle_interaction_ui(true) # 玩家進入，顯示文字
		print(">>> [Portal] 提示文字已浮現")

func _on_body_exited(body: Node) -> void:
	if body is CharacterBase:
		is_player_in_range = false
		_toggle_interaction_ui(false) # 玩家離開，隱藏文字
		print(">>> [Portal] 提示文字已消失")
#endregion
