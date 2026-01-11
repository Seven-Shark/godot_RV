extends CanvasLayer

# 定义信号，通知武器进行调整
signal angle_changed(new_angle: float)
signal radius_changed(new_radius: float)

@onready var slider_angle: HSlider = $VBoxContainer/HSlider_Angle
@onready var label_angle: Label = $VBoxContainer/Label_Angle
@onready var slider_radius: HSlider = $VBoxContainer/HSlider_Radius
@onready var label_radius: Label = $VBoxContainer/Label_Radius


func _ready():
	# 连接滑块信号
	slider_angle.value_changed.connect(_on_angle_changed)
	slider_radius.value_changed.connect(_on_radius_changed)
	
	# 初始化文本
	_update_labels()

func _on_angle_changed(value: float):
	label_angle.text = "角度: %d" % value
	angle_changed.emit(value) # 发出信号

func _on_radius_changed(value: float):
	label_radius.text = "半径: %d" % value
	radius_changed.emit(value) # 发出信号

func _update_labels():
	label_angle.text = "角度: %d" % slider_angle.value
	label_radius.text = "半径: %d" % slider_radius.value
