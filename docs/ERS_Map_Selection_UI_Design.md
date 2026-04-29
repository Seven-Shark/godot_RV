# ERS 保底地图选择界面设计方案

## 1. 界面定位

该界面出现在玩家与传送门交互以后展开的界面。

玩家需要在系统随机提供的 4 个“明日保底地图”中选择 1 个，作为第二天探索的基础地图。

核心交互目标：

```text
查看当前饱食度
查看 4 个明日地图候选
比较地图等级、收益、风险、饱食度消耗
选择地图
如果饱食度不足，确认是否带 Debuff 强行进入
确认后进入第二天
```

## 2. 核心玩家决策

这个界面要让玩家每晚产生以下判断：

```text
我现在的饱食度够不够？
我要稳进 B 级地图攒资源？
还是冒着 Debuff 强行进入高级地图赌收益？
要不要现在吃掉食物，换一个更安全的明天？
```

该界面的核心体验是：

```text
用今晚的资源状态，决定明天的风险与收益。
```

## 3. 界面整体布局

建议使用 16:9 全屏 CanvasLayer。

```text
┌──────────────────────────────────────────────┐
│ 顶部状态栏                                     │
│ 第 X 天夜晚 | 当前饱食度 32/100 | 食物 x5       │
├──────────────────────────────────────────────┤
│                                              │
│        明日广播：请选择一个保底地图             │
│                                              │
│ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ │
│ │地图卡1 │ │地图卡2 │ │地图卡3 │ │地图卡4 │ │
│ └────────┘ └────────┘ └────────┘ └────────┘ │
│                                              │
├──────────────────────────────────────────────┤
│ 左下：食物补给区             右下：选中地图详情 │
│ [食用 1 个食物]              地图名/风险/收益   │
│                              [确认进入明天]    │
└──────────────────────────────────────────────┘
```

## 4. 顶部状态栏

顶部状态栏用于显示玩家当前关键状态。

显示内容：

```text
第 3 天 夜晚
饱食度：32 / 100
食物：5
残响：12
```

节点建议：

```text
TopStatusBar: HBoxContainer
- DayLabel: Label
- SatietyBar: ProgressBar
- SatietyLabel: Label
- FoodLabel: Label
- EchoLabel: Label
```

饱食度颜色：

| 饱食度 | 显示颜色 |
|---|---|
| 70% 以上 | 绿色 |
| 30% - 70% | 黄色 |
| 30% 以下 | 红色 |

## 5. 地图候选卡区域

中央显示 4 张地图卡。每张卡代表一个“明日保底地图”。

每张地图卡必须显示：

```text
地图等级：B / A / S / SSR
地图名称：潮湿森林、碎石荒地、回波塔外围等
主要资源：木头、石头、食物、残响
主要危险：敌人增多、环境侵蚀、夜晚强化
饱食度消耗：20
不足惩罚：1 个 Debuff
```

卡片示例：

```text
┌──────────────────┐
│ A级               │
│ 潮湿森林           │
│                  │
│ 资源：木头 / 食物  │
│ 危险：听觉者增多   │
│                  │
│ 饱食度消耗：20     │
│ 不足：1 Debuff     │
└──────────────────┘
```

节点建议：

```text
MapCardContainer: HBoxContainer
- MapCard_1: Button / PanelContainer
- MapCard_2
- MapCard_3
- MapCard_4
```

推荐把地图卡做成独立场景：

```text
scenes/ui/ers/MapChoiceCard.tscn
scripts/ui/ers/MapChoiceCard.gd
```

## 6. 地图卡交互状态

| 状态 | 表现 |
|---|---|
| 默认 | 普通边框 |
| 鼠标悬停 | 边框变亮，轻微放大 |
| 已选中 | 高亮边框，显示选中标记 |
| 饱食度足够 | 消耗文字正常显示 |
| 饱食度不足 | 消耗文字变红，显示 Debuff 警告 |
| 必定 B 级保底 | 显示“小型保底”标记 |

点击卡片后的逻辑：

```text
1. 设置为当前选中地图
2. 右下角详情区刷新
3. 确认按钮变为可点击
4. 如果饱食度不足，详情区显示 Debuff 警告
```

## 7. 地图详情区

右下角显示当前选中的地图详情。

详情内容：

```text
选中地图：A级 潮湿森林
饱食度需求：20
当前饱食度：12
预计进入状态：饥饿进入
预计 Debuff：2 个

可能获得：
- 木头较多
- 食物少量
- 残响普通

风险：
- 听觉者数量增加
- 黄昏后敌人更活跃
```

饱食度足够时：

```text
状态：正常进入
Debuff：无
```

饱食度不足时：

```text
状态：强行进入
Debuff：2 个
警告：饱食度不足，明天会携带负面状态。
```

节点建议：

```text
SelectedMapPanel: PanelContainer
- SelectedMapNameLabel
- RequiredSatietyLabel
- CurrentSatietyLabel
- EntryStatusLabel
- DebuffWarningLabel
- RewardListLabel
- RiskListLabel
- ConfirmButton
```

确认按钮文字：

| 状态 | 按钮文字 |
|---|---|
| 饱食度足够 | 确认明日地图 |
| 饱食度不足 | 强行进入 |
| 未选择地图 | 请选择地图 |

## 8. 食物补给区

左下角提供补充饱食度的交互。

MVP 版本：

```text
食物数量：5
每个食物恢复：10 饱食度

[食用 1 个食物]
```

点击食用后的逻辑：

```text
如果食物 > 0 且饱食度未满：
    食物 -1
    饱食度 +10
    刷新所有地图卡的可进入状态
否则：
    播放失败反馈
```

节点建议：

```text
FoodPanel: PanelContainer
- FoodCountLabel: Label
- EatFoodButton: Button
```

## 9. 确认进入流程

饱食度足够时：

```text
1. 扣除地图所需饱食度
2. 保存选中地图数据到 GameManager
3. 保存 Debuff 数量为 0
4. 切换到探索场景
```

饱食度不足时，弹出二次确认窗口：

```text
饱食度不足

该地图需要 35 饱食度。
你当前只有 18 饱食度。

强行进入后，明天会获得 2 个负面 Debuff。

是否仍然进入？

[取消] [强行进入]
```

确认强行进入后：

```text
1. 饱食度扣到 0，或扣除当前剩余饱食度
2. 根据缺口计算 Debuff 数量
3. 保存选中地图数据到 GameManager
4. 保存 Debuff 列表或 Debuff 数量
5. 切换到探索场景
```

## 10. Debuff 数量计算

MVP 阶段建议使用简单规则：

| 饱食度缺口 | Debuff 数量 |
|---|---:|
| 缺口 <= 0 | 0 |
| 1 - 10 | 1 |
| 11 - 25 | 2 |
| 26 以上 | 3 |

伪代码：

```gdscript
func calculate_debuff_count(map_data: MapChoiceData) -> int:
	var gap = map_data.satiety_cost - GameDataManager.satiety

	if gap <= 0:
		return 0
	elif gap <= 10:
		return 1
	elif gap <= 25:
		return 2
	else:
		return 3
```

## 11. 地图等级颜色

| 等级 | 颜色 | 定位 |
|---|---|---|
| B | 灰白色 | 安全、普通、保底 |
| A | 蓝色 | 稳定收益 |
| S | 紫色 | 高风险高收益 |
| SSR | 金色 | 特殊事件、稀有机会 |

## 12. 地图生成规则

每天夜晚生成 4 个地图候选。

基础规则：

```text
1. 每天生成 4 张地图候选
2. 必定包含 1 张 B 级地图
3. 其余 3 张根据天数和权重随机
4. 玩家当前已解锁线索可以影响地图主题池
5. 地图选择后保存为第二天的基础地图规则
```

推荐权重：

| 天数 | B | A | S | SSR |
|---|---:|---:|---:|---:|
| 1 - 3 天 | 70% | 30% | 0% | 0% |
| 4 - 7 天 | 50% | 35% | 15% | 0% |
| 8 - 12 天 | 35% | 40% | 20% | 5% |
| 13 天以上 | 25% | 40% | 25% | 10% |

## 13. 地图数据结构建议

建议创建 `MapChoiceData.gd`，作为 Resource。

```gdscript
extends Resource
class_name MapChoiceData

enum Rarity {
	B,
	A,
	S,
	SSR
}

@export var map_id: String
@export var map_name: String
@export var rarity: Rarity = Rarity.B
@export var description: String

@export var satiety_cost: int = 10
@export var main_resources: Array[String] = []
@export var main_risks: Array[String] = []

@export var enemy_multiplier: float = 1.0
@export var resource_multiplier: float = 1.0
@export var food_multiplier: float = 1.0
@export var echo_multiplier: float = 1.0
@export var environment_decay_rate: float = 1.0

@export var possible_debuffs: Array[String] = []
```

## 14. 界面主脚本建议

脚本名：

```text
scripts/ui/ers/ERSMapSelectionUI.gd
```

脚本职责：

```text
1. 打开界面
2. 生成 4 个地图候选
3. 保证至少 1 个 B 级地图
4. 处理地图卡点击
5. 处理食物补给
6. 计算饱食度是否足够
7. 计算 Debuff 数量
8. 确认后通知 GameManager
```

伪代码：

```gdscript
func open():
	visible = true
	generate_map_choices()
	refresh_player_status()
	refresh_cards()

func generate_map_choices():
	map_choices.clear()

	var guaranteed_b_map = get_random_map_by_rarity(MapChoiceData.Rarity.B)
	map_choices.append(guaranteed_b_map)

	while map_choices.size() < 4:
		var rarity = roll_rarity_by_day(GameManager.current_day)
		var map = get_random_map_by_rarity(rarity)
		map_choices.append(map)

	map_choices.shuffle()

func select_map(map_data):
	selected_map = map_data
	refresh_selected_map_panel()

func eat_food():
	if GameDataManager.food <= 0:
		return

	if GameDataManager.satiety >= GameDataManager.max_satiety:
		return

	GameDataManager.food -= 1
	GameDataManager.satiety += 10
	GameDataManager.satiety = min(GameDataManager.satiety, GameDataManager.max_satiety)

	refresh_all()

func confirm_selected_map():
	if selected_map == null:
		return

	var debuff_count = calculate_debuff_count(selected_map)

	if debuff_count > 0:
		show_force_enter_confirm(debuff_count)
	else:
		enter_next_day(0)

func enter_next_day(debuff_count):
	GameDataManager.satiety = max(0, GameDataManager.satiety - selected_map.satiety_cost)

	GameManager.pending_map_choice = selected_map
	GameManager.pending_debuff_count = debuff_count

	GameManager.goto_survival_scene()
```

## 15. 推荐场景节点结构

```text
ERSMapSelectionUI.tscn
CanvasLayer
└─ Root: Control
   ├─ Background: ColorRect
   ├─ TopStatusBar: HBoxContainer
   │  ├─ DayLabel: Label
   │  ├─ SatietyBar: ProgressBar
   │  ├─ SatietyLabel: Label
   │  ├─ FoodLabel: Label
   │  └─ EchoLabel: Label
   │
   ├─ TitleLabel: Label
   │
   ├─ MapCardContainer: HBoxContainer
   │  ├─ MapChoiceCard
   │  ├─ MapChoiceCard
   │  ├─ MapChoiceCard
   │  └─ MapChoiceCard
   │
   ├─ FoodPanel: PanelContainer
   │  ├─ FoodCountLabel: Label
   │  └─ EatFoodButton: Button
   │
   ├─ SelectedMapPanel: PanelContainer
   │  ├─ SelectedMapNameLabel: Label
   │  ├─ RequiredSatietyLabel: Label
   │  ├─ CurrentSatietyLabel: Label
   │  ├─ EntryStatusLabel: Label
   │  ├─ DebuffWarningLabel: Label
   │  ├─ RewardListLabel: Label
   │  ├─ RiskListLabel: Label
   │  └─ ConfirmButton: Button
   │
   └─ ForceEnterDialog: ConfirmationDialog
```

## 16. MVP 必做功能清单

```text
[ ] 打开 ERS 保底地图界面
[ ] 显示当前天数
[ ] 显示当前饱食度
[ ] 显示当前食物数量
[ ] 随机生成 4 个地图候选
[ ] 保证至少 1 个 B 级地图
[ ] 地图卡显示等级、名称、资源、风险、饱食度消耗
[ ] 点击地图卡后显示详情
[ ] 食用食物增加饱食度
[ ] 饱食度足够时正常确认
[ ] 饱食度不足时显示 Debuff 警告
[ ] 饱食度不足确认时弹出二次确认
[ ] 确认后保存选中地图
[ ] 确认后保存 Debuff 数量
[ ] 切换到第二天探索场景
```

## 17. 后续扩展方向

```text
1. 地图卡支持 ERS 线索追加改写
2. 地图候选受玩家已解锁线索影响
3. 食物分品质，恢复不同饱食度
4. Debuff 从随机数量变成具体负面状态
5. SSR 地图绑定 Boss、剧情、特殊区域
6. 地图详情支持预览特殊事件
7. 玩家可以消耗残响刷新地图候选
8. 玩家可以锁定一张地图，刷新其余地图
```
