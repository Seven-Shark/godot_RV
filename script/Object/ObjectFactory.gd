@tool
extends Node
class_name ObjectFactory

#region 1. 基础配置
@export_group("1. 基础信息")
@export var object_name: String = "NewObject" ## 生成的物件名称 (如 Tree_Oak)
@export var sprite_texture: Texture2D ## 物件的外观图片
@export var max_health: float = 50.0 ## 物件的血量

@export_group("2. 掉落配置")
# 这里定义一个简单的结构，用来配置掉落
# 数组里每个元素代表：[掉落物预制体, 最小数量, 最大数量, 掉落率(0-1)]
@export var loot_config: Array[Dictionary] = [] 
# 提示：在编辑器里点击数组添加元素时，Dictionary 看起来是空的，
# 你需要手动添加键值对，这有点麻烦。
# ===> 更推荐的方法是下面这种：使用自定义资源列表，或者简单的辅助变量 <===

# 为了方便，我们这里简化一下：只支持配置一种主要掉落物 (你可以按需扩展)
@export var main_drop_item: PackedScene ## 主要掉落物 (如 Wood_Item.tscn)
@export var drop_min: int = 1
@export var drop_max: int = 3
@export var drop_chance: float = 1.0

@export_group("3. 输出设置")
@export_dir var save_path: String = "res://scenes/objects/generated/" ## 生成文件的保存路径
@export var base_scene_path: String = "res://scenes/object_scenes/Object_Base.tscn" ## 你的基础物件模板路径

@export_group("4. 操作")
@export var _generate_button: bool = false: ## 点击此勾选框开始生成！
	set(value):
		if value:
			_generate_button = false # 自动回弹
			create_object()
#endregion

func create_object():
	print(">>> 开始生成物件: %s" % object_name)
	
	# 1. 检查必要条件
	if not sprite_texture:
		push_error("错误：请先设置 Sprite Texture！")
		return
	if not FileAccess.file_exists(base_scene_path):
		push_error("错误：找不到基础场景模板，请检查 base_scene_path")
		return
	
	# 2. 实例化基础场景
	var base_packed = load(base_scene_path)
	var instance = base_packed.instantiate()
	instance.name = object_name
	
	# 3. 修改属性
# 3. 修改属性
	# --- 修改图片 (增强版：兼容 Sprite2D 和 AnimatedSprite2D) ---
	var stats_node = instance.get_node_or_null("StatsComponent")
	
	if stats_node:
		stats_node.max_health = max_health
		stats_node.current_health = max_health # 初始血量也要填满
		print("   已配置血量: %s" % max_health)
	else:
		push_warning("警告：生成的实例中找不到名为 'StatsComponent' 的子节点，血量未设置！")
	
	# 4. 生成掉落数据 (LootData)
	# 我们直接在代码里创建一个新的 LootData 资源，并嵌入到场景里
	if main_drop_item:
		var new_loot = LootData.new() # 假设你的 LootData 是 class_name LootData
		new_loot.item_scene = main_drop_item
		new_loot.min_count = drop_min
		new_loot.max_count = drop_max
		new_loot.drop_chance = drop_chance
		
		# 将其添加到 instance 的掉落表中
		# 注意：这里需要你的 ObjectBase 有一个 exported var loot_table: Array[LootData]
		instance.loot_table.append(new_loot)
		print("   已配置掉落: %s (x%d-%d)" % [main_drop_item.resource_name, drop_min, drop_max])
	
	# 5. 打包并保存
	# 这一步非常关键：必须把所有子节点的 owner 设为 instance，否则保存后子节点会消失
	_set_owner_recursive(instance, instance)
	
	var final_packed = PackedScene.new()
	var result = final_packed.pack(instance)
	
	if result == OK:
		# 确保目录存在
		var dir = DirAccess.open("res://")
		if not dir.dir_exists(save_path):
			dir.make_dir_recursive(save_path)
			
		var full_path = save_path + object_name + ".tscn"
		var save_err = ResourceSaver.save(final_packed, full_path)
		if save_err == OK:
			print("✅ 成功！物件已保存至: " + full_path)
			# 刷新编辑器文件系统，让你立刻能看到文件
			EditorInterface.get_resource_filesystem().scan()
		else:
			push_error("保存失败，错误码: %d" % save_err)
	else:
		push_error("打包失败")
		
	instance.queue_free() # 清理内存

# [辅助] 递归设置 owner，这是 Godot 脚本生成场景的必修课
func _set_owner_recursive(node: Node, root: Node):
	if node != root:
		node.owner = root
	for child in node.get_children():
		_set_owner_recursive(child, root)

# [辅助] 自动根据图片大小调整碰撞圆
func _auto_resize_collider(instance: Node, texture: Texture2D):
	# 尝试找碰撞体节点
	var collider = instance.get_node_or_null("CollisionShape2D")
	if collider and texture:
		# 假设我们用圆形碰撞，半径设为图片宽度的一半 * 0.8 (稍微小一点)
		var radius = (texture.get_width() / 2.0) * 0.8
		
		# 创建一个新的形状资源（不要改原来的，否则会影响所有物件）
		var new_shape = CircleShape2D.new()
		new_shape.radius = radius
		collider.shape = new_shape
		print("   已自动计算碰撞半径: %.1f" % radius)
