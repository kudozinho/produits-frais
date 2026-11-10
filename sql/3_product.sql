-- Ibrahim : nettoyage de product.csv

CREATE OR REPLACE TABLE product_clean AS
SELECT
    "Item Code" AS item_code,
    trim("Item Name") AS item_name,                            -- 4 noms avaient un espace en trop à la fin
    "Category Code" AS category_code,
    replace("Category Name", chr(160), ' ') AS category_name   -- espace invisible dans "Flower/Leaf Vegetables"
FROM read_csv('data/product.csv', all_varchar = true);
