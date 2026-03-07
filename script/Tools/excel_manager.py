import pandas as pd
import os
import sys

# Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
DATA_DIR = os.path.join(PROJECT_ROOT, "script", "Data")
CSV_DIR = os.path.join(DATA_DIR, "CSVs")
EXCEL_PATH = os.path.join(DATA_DIR, "GameData.xlsx")

ITEMS_CSV = os.path.join(CSV_DIR, "Items.txt")
RECIPES_CSV = os.path.join(CSV_DIR, "Recipes.txt")

def create_excel_from_csv():
    """Reads existing CSVs and creates a new Excel file if it doesn't exist."""
    if os.path.exists(EXCEL_PATH):
        print(f"Excel file already exists at: {EXCEL_PATH}")
        return

    print("Creating Excel file from CSVs...")
    
    with pd.ExcelWriter(EXCEL_PATH, engine='openpyxl') as writer:
        # Items
        if os.path.exists(ITEMS_CSV):
            df_items = pd.read_csv(ITEMS_CSV)
            df_items.to_excel(writer, sheet_name='Items', index=False)
            print("  - Added Items sheet")
        else:
            print(f"  - Warning: {ITEMS_CSV} not found")

        # Recipes
        if os.path.exists(RECIPES_CSV):
            df_recipes = pd.read_csv(RECIPES_CSV)
            
            # Split 'ingredients' column into multiple columns for easier editing in Excel
            if 'ingredients' in df_recipes.columns:
                # Assuming max 4 ingredients for template, can be more
                max_ingredients = 4
                for i in range(1, max_ingredients + 1):
                    df_recipes[f'mat_{i}_id'] = ''
                    df_recipes[f'mat_{i}_count'] = ''
                
                # Parse existing ingredients
                for idx, row in df_recipes.iterrows():
                    ing_str = str(row['ingredients'])
                    if pd.isna(ing_str) or ing_str == 'nan':
                        continue
                        
                    parts = ing_str.split(';')
                    for i, part in enumerate(parts):
                        if i >= max_ingredients: break
                        if ':' in part:
                            item_id, count = part.split(':')
                            df_recipes.at[idx, f'mat_{i+1}_id'] = item_id
                            df_recipes.at[idx, f'mat_{i+1}_count'] = count

                # Drop original ingredients column for Excel view
                df_recipes = df_recipes.drop(columns=['ingredients'])

            df_recipes.to_excel(writer, sheet_name='Recipes', index=False)
            print("  - Added Recipes sheet (with split ingredient columns)")
        else:
            print(f"  - Warning: {RECIPES_CSV} not found")
            
    print(f"Excel file created successfully: {EXCEL_PATH}")

def update_csv_from_excel():
    """Reads the Excel file and updates the CSV files."""
    if not os.path.exists(EXCEL_PATH):
        print(f"Error: Excel file not found at {EXCEL_PATH}")
        return

    print("Updating CSVs from Excel...")
    
    try:
        # Read Excel file
        xls = pd.ExcelFile(EXCEL_PATH)
        
        # Items
        if 'Items' in xls.sheet_names:
            df_items = pd.read_excel(xls, 'Items')
            # Ensure directory exists
            os.makedirs(CSV_DIR, exist_ok=True)
            df_items.to_csv(ITEMS_CSV, index=False)
            print(f"  - Updated {ITEMS_CSV}")
        else:
            print("  - Warning: 'Items' sheet not found in Excel")

        # Recipes
        if 'Recipes' in xls.sheet_names:
            df_recipes = pd.read_excel(xls, 'Recipes')
            
            # Reconstruct 'ingredients' column from mat_X_id/count columns
            ingredients_list = []
            
            # Check if we have split columns
            has_split_cols = any(col.startswith('mat_') for col in df_recipes.columns)
            
            if has_split_cols:
                for _, row in df_recipes.iterrows():
                    parts = []
                    # Check up to 10 potential slots
                    for i in range(1, 11):
                        id_col = f'mat_{i}_id'
                        count_col = f'mat_{i}_count'
                        
                        if id_col in df_recipes.columns and count_col in df_recipes.columns:
                            item_id = row[id_col]
                            count = row[count_col]
                            
                            # Skip empty entries
                            if pd.isna(item_id) or str(item_id).strip() == '':
                                continue
                                
                            # Default count to 1 if missing but ID exists
                            if pd.isna(count) or str(count).strip() == '':
                                count = 1
                            else:
                                try:
                                    count = int(float(count)) # Handle 1.0 from Excel
                                except:
                                    count = 1
                                    
                            parts.append(f"{str(item_id).strip()}:{count}")
                            
                    ingredients_list.append(";".join(parts))
                
                # Add/Overwrite ingredients column
                df_recipes['ingredients'] = ingredients_list
                
                # Drop the split columns from CSV output to keep it clean
                cols_to_drop = [c for c in df_recipes.columns if c.startswith('mat_')]
                df_recipes = df_recipes.drop(columns=cols_to_drop)
            
            os.makedirs(CSV_DIR, exist_ok=True)
            df_recipes.to_csv(RECIPES_CSV, index=False)
            print(f"  - Updated {RECIPES_CSV}")
        else:
            print("  - Warning: 'Recipes' sheet not found in Excel")
            
    except Exception as e:
        print(f"Error processing Excel file: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        command = sys.argv[1]
        if command == "init":
            create_excel_from_csv()
        elif command == "export":
            update_csv_from_excel()
        else:
            print(f"Unknown command: {command}")
            print("Usage: python excel_manager.py [init|export]")
    else:
        # Default behavior: if Excel exists, export to CSV. If not, create from CSV.
        if os.path.exists(EXCEL_PATH):
            update_csv_from_excel()
        else:
            create_excel_from_csv()
