-- Nettoyage de product : un produit par ligne, base de dim_product
-- BigQuery. Remplacer project_id.dataset_id par votre projet et dataset.

CREATE OR REPLACE TABLE `project_id.dataset_id.product_clean` AS
SELECT
  -- Item Code en texte : sur 15 chiffres, il ne doit jamais être traité comme un nombre
  TRIM(CAST(`Item Code` AS STRING)) AS item_code,
  -- Espaces en trop sur 4 noms, espaces insécables remplacés par des espaces normaux
  TRIM(REPLACE(`Item Name`, '\u00a0', ' ')) AS item_name,
  -- Code catégorie = identifiant, pas un nombre à calculer
  CAST(`Category Code` AS STRING) AS category_code,
  -- "Flower/Leaf Vegetables" contient un espace insécable sur ses 100 lignes : un filtre tapé au clavier ne le trouverait pas
  TRIM(REPLACE(`Category Name`, '\u00a0', ' ')) AS category_name,
  -- Conditionnement caché dans le nom : l'unité "kilo" de transaction est douteuse pour ces produits
  CASE
    WHEN LOWER(`Item Name`) LIKE '%(bag)%' OR LOWER(`Item Name`) LIKE '%(small bag)%' THEN 'sachet'
    WHEN LOWER(`Item Name`) LIKE '%(box)%' OR LOWER(`Item Name`) LIKE '%gift box%' THEN 'boite'
    WHEN LOWER(`Item Name`) LIKE '%(bunch)%' THEN 'botte'
    WHEN LOWER(`Item Name`) LIKE '%(ea)%' THEN 'piece'
    ELSE 'kg'
  END AS packaging,
  -- Même nom sous plusieurs codes : produits distincts, on les garde et on les signale
  COUNT(*) OVER (PARTITION BY TRIM(REPLACE(`Item Name`, '\u00a0', ' '))) > 1 AS is_duplicate_name
FROM `project_id.dataset_id.product_raw`;

-- Contrôles : le script s'arrête si l'un échoue
ASSERT (
  SELECT COUNT(*) FROM `project_id.dataset_id.product_clean`
  WHERE item_code IS NULL OR NOT REGEXP_CONTAINS(item_code, r'^\d{15}$')
) = 0 AS 'item_code manquant ou pas sur 15 chiffres';

ASSERT (
  SELECT COUNT(*) - COUNT(DISTINCT item_code) FROM `project_id.dataset_id.product_clean`
) = 0 AS 'item_code en double';

ASSERT (
  SELECT COUNT(*) FROM (
    SELECT category_code FROM `project_id.dataset_id.product_clean`
    GROUP BY category_code HAVING COUNT(DISTINCT category_name) > 1
  )
) = 0 AS 'un code catégorie a plusieurs noms';

ASSERT (
  SELECT COUNT(*) FROM `project_id.dataset_id.product_clean`
  WHERE STRPOS(item_name, '\u00a0') > 0 OR STRPOS(category_name, '\u00a0') > 0
) = 0 AS 'espace insécable restant';
