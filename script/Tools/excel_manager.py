import pandas as pd
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
DATA_DIR = os.path.join(PROJECT_ROOT, "script", "Data")
CSV_DIR = os.path.join(DATA_DIR, "CSVs")

EXCEL_CANDIDATES = [
    os.path.join(PROJECT_ROOT, "SoData", "GameData.xlsx"),
    os.path.join(DATA_DIR, "GameData.xlsx"),
]

ITEMS_CSV = os.path.join(CSV_DIR, "Items.txt")
RECIPES_CSV = os.path.join(CSV_DIR, "Recipes.txt")
MAP_ELEMENTS_CSV = os.path.join(CSV_DIR, "MapElements.txt")


def resolve_excel_path_for_export():
    for path in EXCEL_CANDIDATES:
        if os.path.exists(path):
            return path
    return None


def resolve_excel_path_for_init():
    existing = resolve_excel_path_for_export()
    if existing:
        return existing
    return EXCEL_CANDIDATES[0]


def create_excel_from_csv():
    excel_path = resolve_excel_path_for_init()
    if os.path.exists(excel_path):
        print(f"Excel file already exists at: {excel_path}")
        return

    os.makedirs(os.path.dirname(excel_path), exist_ok=True)
    print(f"Creating Excel file from text files... ({excel_path})")

    with pd.ExcelWriter(excel_path, engine="openpyxl") as writer:
        if os.path.exists(ITEMS_CSV):
            df_items = pd.read_csv(ITEMS_CSV)
            df_items.to_excel(writer, sheet_name="Items", index=False)
            print("  - Added Items sheet")
        else:
            print(f"  - Warning: {ITEMS_CSV} not found")

        if os.path.exists(RECIPES_CSV):
            df_recipes = pd.read_csv(RECIPES_CSV)
            if "ingredients" in df_recipes.columns:
                max_ingredients = 8
                for i in range(1, max_ingredients + 1):
                    df_recipes[f"mat_{i}_id"] = ""
                    df_recipes[f"mat_{i}_count"] = ""

                for idx, row in df_recipes.iterrows():
                    ing_str = str(row["ingredients"])
                    if pd.isna(ing_str) or ing_str == "nan":
                        continue

                    parts = ing_str.split(";")
                    for i, part in enumerate(parts):
                        if i >= max_ingredients:
                            break
                        if ":" in part:
                            item_id, count = part.split(":", 1)
                            df_recipes.at[idx, f"mat_{i+1}_id"] = item_id
                            df_recipes.at[idx, f"mat_{i+1}_count"] = count

                df_recipes = df_recipes.drop(columns=["ingredients"])

            df_recipes.to_excel(writer, sheet_name="Recipes", index=False)
            print("  - Added Recipes sheet")
        else:
            print(f"  - Warning: {RECIPES_CSV} not found")

        if os.path.exists(MAP_ELEMENTS_CSV):
            df_map_elements = pd.read_csv(MAP_ELEMENTS_CSV)
            df_map_elements.to_excel(writer, sheet_name="MapElements", index=False)
            print("  - Added MapElements sheet")
        else:
            df_map_elements = pd.DataFrame([
                {
                    "id": "__desc__",
                    "name": "中文说明行",
                    "category": "分类：map_base=地图基底；terrain/plant/mineral/food/creature/water/site/hazard=地图元素分类",
                    "quality": "品质：COMMON/RARE/EPIC/LEGENDARY",
                    "description": "这里填写给玩家看的地图元素说明",
                    "count": "调试背包初始数量",
                    "is_base": "是否可作为基底 TRUE/FALSE",
                    "is_material": "是否可作为材料 TRUE/FALSE",
                    "props": "属性键值，用分号分隔，例如 风险:1;资源:2",
                    "pack_probability": "卡包内抽取权重：同分类卡包内按权重随机，品质越高建议越低",
                    "icon_path": "可选图标路径 res://..."
                },
                {
                    "id": "plain_map",
                    "name": "平原地图",
                    "category": "map_base",
                    "quality": "COMMON",
                    "description": "基础地图基底。适合承载低风险、资源均衡的明日地图组合。",
                    "count": 1,
                    "is_base": "TRUE",
                    "is_material": "FALSE",
                    "props": "平原:1;风险:1",
                    "pack_probability": 0,
                    "icon_path": ""
                },
                {
                    "id": "tree",
                    "name": "树木",
                    "category": "plant",
                    "quality": "COMMON",
                    "description": "提高树木、林地和木材资源出现概率。",
                    "count": 5,
                    "is_base": "FALSE",
                    "is_material": "TRUE",
                    "props": "森林:1;木材:2",
                    "pack_probability": 100,
                    "icon_path": ""
                }
            ])
            df_map_elements.to_excel(writer, sheet_name="MapElements", index=False)
            print("  - Added MapElements sheet template")

    print(f"Excel file created successfully: {excel_path}")


def update_csv_from_excel():
    excel_path = resolve_excel_path_for_export()
    if not excel_path:
        print("Error: Excel file not found. Checked paths:")
        for p in EXCEL_CANDIDATES:
            print(f"  - {p}")
        return 1

    print(f"Updating text files from Excel... ({excel_path})")

    try:
        xls = pd.ExcelFile(excel_path)
        os.makedirs(CSV_DIR, exist_ok=True)

        if "Items" in xls.sheet_names:
            df_items = pd.read_excel(xls, "Items")
            df_items.to_csv(ITEMS_CSV, index=False)
            print(f"  - Updated {ITEMS_CSV}")
        else:
            print("  - Warning: 'Items' sheet not found in Excel")

        if "Recipes" in xls.sheet_names:
            df_recipes = pd.read_excel(xls, "Recipes")

            has_split_cols = any(str(col).startswith("mat_") for col in df_recipes.columns)
            if has_split_cols:
                ingredients_list = []
                for _, row in df_recipes.iterrows():
                    parts = []
                    for i in range(1, 21):
                        id_col = f"mat_{i}_id"
                        count_col = f"mat_{i}_count"
                        if id_col not in df_recipes.columns or count_col not in df_recipes.columns:
                            continue

                        item_id = row[id_col]
                        count = row[count_col]
                        if pd.isna(item_id) or str(item_id).strip() == "":
                            continue

                        if pd.isna(count) or str(count).strip() == "":
                            count = 1
                        else:
                            try:
                                count = int(float(count))
                            except Exception:
                                count = 1

                        parts.append(f"{str(item_id).strip()}:{count}")

                    ingredients_list.append(";".join(parts))

                df_recipes["ingredients"] = ingredients_list
                cols_to_drop = [c for c in df_recipes.columns if str(c).startswith("mat_")]
                df_recipes = df_recipes.drop(columns=cols_to_drop)

            df_recipes.to_csv(RECIPES_CSV, index=False)
            print(f"  - Updated {RECIPES_CSV}")
        else:
            print("  - Warning: 'Recipes' sheet not found in Excel")

        if "MapElements" in xls.sheet_names:
            df_map_elements = pd.read_excel(xls, "MapElements")
            df_map_elements.to_csv(MAP_ELEMENTS_CSV, index=False)
            print(f"  - Updated {MAP_ELEMENTS_CSV}")
        else:
            print("  - Warning: 'MapElements' sheet not found in Excel")

        return 0
    except Exception as e:
        print(f"Error processing Excel file: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    if len(sys.argv) > 1:
        command = sys.argv[1]
        if command == "init":
            create_excel_from_csv()
            sys.exit(0)
        elif command == "export":
            sys.exit(update_csv_from_excel())
        else:
            print(f"Unknown command: {command}")
            print("Usage: python excel_manager.py [init|export]")
            sys.exit(1)
    else:
        if resolve_excel_path_for_export():
            sys.exit(update_csv_from_excel())
        create_excel_from_csv()
        sys.exit(0)
