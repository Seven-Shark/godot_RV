# Excel 配置工具 (Excel Configuration Tool)

此工具允许您使用 Excel 表格 (`.xlsx`) 来配置游戏数据，而不需要直接编辑 CSV。

## 准备工作
为了支持 Excel 文件读取，需要安装 Python 和相关库。
1. 确保已安装 Python。
2. 安装依赖库:
   ```bash
   pip install pandas openpyxl
   ```

## 文件位置
- **Excel 数据表**: `res://SoData/GameData.xlsx`
- **导入脚本**: `res://script/Tools/CSVImporter.gd`
- **Python 脚本**: `res://script/Tools/excel_manager.py` (自动调用，无需手动运行)

## 如何使用
1. 打开 `SoData/GameData.xlsx` 进行编辑。
   - **Items 分页**: 配置物品数据。
   - **Recipes 分页**: 配置合成配方。
	 - 您可以使用 `ingredients` 字符串列 (例如 `wood:1;stone:2`)。
	 - **或者** 使用更方便的拆分列：`mat_1_id`, `mat_1_count`, `mat_2_id`, `mat_2_count` 等。工具会自动将它们合并。
   - **MapElements 分页**: 配置地图合成用的地图基底和地图元素。
	 - 第 2 行 `__desc__` 是中文说明行，仅用于查看字段含义，导入和合成台读取时会跳过。
	 - `category` 使用 `map_base` 表示地图基底；地图元素可使用 `terrain`、`plant`、`mineral`、`food`、`creature`、`water`、`site`、`hazard` 分类。
	 - `props` 使用 `键:值;键:值` 格式，例如 `森林:1;资源:1`。
	 - `pack_probability` 表示该地图元素在同分类卡包内的抽取权重；同一分类下按权重归一化为最终概率。
   - 您可以自由使用 Excel 的功能（公式、颜色等），只要保持列头名称不变。
2. 在 Godot 中打开 `res://script/Tools/CSVImporter.gd`。
3. 点击 **文件 > 运行** (File > Run) (或按 `Ctrl+Shift+X`)。
4. 脚本会自动：
   - 调用 Python 将 Excel 数据导出为 CSV。
   - 读取 CSV 并更新 `.tres` 资源文件。

## 注意事项
- 如果 `GameData.xlsx` 不存在，脚本会尝试从现有的 CSV 文件生成一个初始版本。
- 请勿修改 Excel 表格的第一行（列标题），否则导入可能会失败。
- 编辑 `SoData/GameData.xlsx` 时请先关闭 Excel，再运行导入工具，否则脚本可能无法保存或导出最新数据。
