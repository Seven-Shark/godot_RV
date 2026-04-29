extends Button
class_name MapChoiceCard

signal card_selected(card: MapChoiceCard)

@onready var rarity_label: Label = $VBox/RarityLabel
@onready var name_label: Label = $VBox/NameLabel
@onready var resource_label: Label = $VBox/ResourceLabel
@onready var risk_label: Label = $VBox/RiskLabel
@onready var satiety_label: Label = $VBox/SatietyLabel
@onready var debuff_label: Label = $VBox/DebuffLabel
@onready var tag_label: Label = $TopTag

var map_data: MapChoiceData = null

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)

func setup(data: MapChoiceData, current_satiety: int, selected: bool) -> void:
	map_data = data
	if not map_data:
		return

	rarity_label.text = _rarity_text(map_data.rarity) + "级"
	rarity_label.modulate = _rarity_color(map_data.rarity)
	name_label.text = map_data.map_name
	resource_label.text = "资源：" + " / ".join(map_data.main_resources)
	risk_label.text = "危险：" + " / ".join(map_data.main_risks)
	satiety_label.text = "饱食度消耗：%d" % map_data.satiety_cost

	var debuff = _calculate_debuff_count(current_satiety, map_data.satiety_cost)
	debuff_label.text = "不足：%d Debuff" % debuff
	debuff_label.visible = debuff > 0
	satiety_label.modulate = Color(1.0, 0.35, 0.35) if debuff > 0 else Color(1, 1, 1)

	tag_label.visible = map_data.guaranteed_safe_choice
	tag_label.text = "小型保底"

	_apply_selected_style(selected)

func _on_pressed() -> void:
	card_selected.emit(self)

func _on_mouse_entered() -> void:
	if button_pressed:
		return
	scale = Vector2.ONE * 1.02

func _on_mouse_exited() -> void:
	if button_pressed:
		return
	scale = Vector2.ONE

func _apply_selected_style(selected: bool) -> void:
	button_pressed = selected
	scale = Vector2.ONE if not selected else Vector2.ONE * 1.02
	modulate = Color(1, 1, 1, 1) if selected else Color(0.92, 0.92, 0.92, 1)

func _rarity_text(rarity: int) -> String:
	match rarity:
		MapChoiceData.Rarity.B:
			return "B"
		MapChoiceData.Rarity.A:
			return "A"
		MapChoiceData.Rarity.S:
			return "S"
		MapChoiceData.Rarity.SSR:
			return "SSR"
		_:
			return "B"

func _rarity_color(rarity: int) -> Color:
	match rarity:
		MapChoiceData.Rarity.B:
			return Color(0.86, 0.86, 0.86)
		MapChoiceData.Rarity.A:
			return Color(0.48, 0.68, 1.0)
		MapChoiceData.Rarity.S:
			return Color(0.77, 0.55, 1.0)
		MapChoiceData.Rarity.SSR:
			return Color(1.0, 0.84, 0.4)
		_:
			return Color(1, 1, 1)

func _calculate_debuff_count(current_satiety: int, satiety_cost: int) -> int:
	var gap := satiety_cost - current_satiety
	if gap <= 0:
		return 0
	if gap <= 10:
		return 1
	if gap <= 25:
		return 2
	return 3
