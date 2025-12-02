extends CharacterBody2D
class_name CharacterBase




@export var character_type:CharacterType = CharacterType.ITEM

# 【新增通用變量】CharacterType 列表，定义该角色会追踪哪些类型的对象
# 必须在 Player.gd 或 Enemy.gd 的 _init 中设置此列表
@export var target_types: Array[CharacterType] = [] 


# --- 【通用目標追蹤與區域管理變量】 ---
# 角色範圍內的所有目標列表 (保持進入順序，從 Player.gd 移入)
var enter_Character: Array[CharacterBase] = []
# 當前被鎖定的最近目標 (從 Player.gd 移入，用於 _process 單次輸出)
var current_target: CharacterBase = null 
# ------------------------------------

# ... (省略其他 @export 变量) ...

@onready var detection_Area = $DetectionArea

# 【新增】安全的箭頭節點引用 (如果 Player 场景有 TargetArrow，它会被获取)
@onready var target_arrow: Sprite2D = get_node_or_null("TargetArrow") 


func _ready():
	# 在基類中連接信號，所有子類自動獲得區域識別功能
	if is_instance_valid(detection_Area):
		detection_Area.body_entered.connect(_on_detection_area_body_entered)
		detection_Area.body_exited.connect(_on_detection_area_body_exited)


# ... (省略 Turn() 函数) ...

# ----------------------------------------------------
# 【核心功能區：通用方法】
# ----------------------------------------------------

# 用於判斷距離角色最近的對象 (已修正為使用 target_types 列表進行過濾)
func get_closest_target() -> CharacterBase:

	var required_types = target_types # 獲取需要的目標類型列表
	var overlapping_bodies:Array = detection_Area.get_overlapping_bodies()
	var closest_target: CharacterBase = null
	var closest_distance_sq:float = INF
	var self_position:Vector2 = global_position

	for body in overlapping_bodies:
		# 【關鍵修正】過濾：確保是 CharacterBase, 不是自己, 且類型在目標列表中
		if body is CharacterBase and body != self and required_types.has(body.character_type):
			var target:CharacterBase = body

			var distance_sq = self_position.distance_squared_to(target.global_position)

			if distance_sq < closest_distance_sq:
				closest_distance_sq = distance_sq
				closest_target = target

	return closest_target

# 【新增方法】用於旋轉箭頭指向目標 (供 _process 調用)
func rotate_arrow_to_target(target: CharacterBase):
	if is_instance_valid(target_arrow):
		if target:
			var direction_vector: Vector2 = target.global_position - global_position
			var target_rotation: float = direction_vector.angle()
			
			target_arrow.rotation = target_rotation
			target_arrow.visible = true
			
		else:
			target_arrow.visible = false

# ----------------------------------------------------
# 【區域信號處理：入隊/出隊/補位邏輯】(從 Player.gd 遷移)
# ----------------------------------------------------

# 處理對象進入區域 (通用)
func _on_detection_area_body_entered(body: Node2D):
	# 檢查 body 是否是 CharacterBase 且其類型在目标列表中
	if body is CharacterBase and target_types.has(body.character_type):
		var target_character: CharacterBase = body
		
		enter_Character.append(target_character)
		
		var enter_ID = enter_Character.size()
		
		# 【修正】 set_taget_tag -> set_target_tag (已在 Enemy.gd 中修正)
		target_character.set_target_tag(enter_ID) 
		
		print(name, " detected ", target_character.name , ". ID: ", enter_ID)


# 處理對象離開區域 (通用)
func _on_detection_area_body_exited(body: Node2D):
	if body is CharacterBase and target_types.has(body.character_type):
		var target_character: CharacterBase = body
		
		var index = enter_Character.find(target_character)
		if index != -1:
			# 【關鍵修正】獲取原始 ID (在移除前，用於打印)
			var original_tag = index + 1
			
			enter_Character.remove_at(index)
			
			print(target_character.name, " left ", name, "'s area. Old ID: ", original_tag)
			
			# 重新對所有剩餘目標打標籤 (自動補位後，必須重排標籤)
			_update_all_enter_Character()
			
			# 通知離開的目標清除 ID
			target_character.clear_target_tag() # 需要在 Enemy.gd 中实现


# 【補全】重新對所有剩餘目標進行標籤排序 (補位邏輯)
func _update_all_enter_Character():
	for i in range(enter_Character.size()):
		var target: CharacterBase = enter_Character[i]
		var new_tag = i + 1 
		
		# 傳遞新的 ID
		target.set_target_tag(new_tag)
		
# ... (省略 region Taking Damage) ...
