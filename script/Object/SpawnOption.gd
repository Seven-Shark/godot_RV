extends Resource
class_name SpawnOption

@export var enemy_scene: PackedScene ## 敌人的场景文件 (.tscn)
@export var weight: float = 1.0      ## 权重 (权重越大，随机到的概率越高)
