extends Resource
class_name DayLoopConfig

enum PhaseType { DAY, DUSK, NIGHT }

@export_group("Phase Info")
@export var phase_name: String = "Day"
@export var phase_type: PhaseType = PhaseType.DAY
@export var duration: float = 30.0 ## 阶段持续时间 (秒)
@export var hud_color: Color = Color.WHITE ## HUD 倒计时扇形的颜色

@export_group("Spawning")
@export var phase_spawn_list: Array[SpawnData] ## 该阶段开始时生成的物件列表
@export var clear_previous_enemies: bool = false ## (可选) 是否清除上一阶段的敌人
