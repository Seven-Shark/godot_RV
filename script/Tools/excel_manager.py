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
