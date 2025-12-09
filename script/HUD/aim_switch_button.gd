extends CheckButton

@onready var player: Player = $"../../Player"
@onready var label: Label = $Label


	
func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if player and is_instance_valid(player):
		player.toggle_aim_mode()
		
	if player.player_current_aim_mode == player.AimMode_Type.AUTO_NEAREST:
		label.text = "自动瞄准"
	else:
		label.text = "鼠标瞄准"
