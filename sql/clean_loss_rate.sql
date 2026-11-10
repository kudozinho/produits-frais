-- Nettoyage de loss_rate : un taux de perte par produit, rattaché à dim_product
-- BigQuery. Lancer clean_product.sql avant.

-- Contrôles sur la donnée brute avant de la transformer
ASSERT (
  SELECT COUNT(*) - COUNT(DISTINCT `Item Code`) FROM `project_id.dataset_id.loss_rate_raw`
) = 0 AS 'item_code en double dans loss_rate';

-- Relation 1 pour 1 : mêmes codes des deux côtés
ASSERT (
  SELECT COUNT(*)
  FROM `project_id.dataset_id.loss_rate_raw` AS l
  FULL OUTER JOIN `project_id.dataset_id.product_clean` AS p
    ON TRIM(CAST(l.`Item Code` AS STRING)) = p.item_code
  WHERE l.`Item Code` IS NULL OR p.item_code IS NULL
) = 0 AS 'codes différents entre loss_rate et product';

-- Item Name doit être identique à product avant d'être supprimé
ASSERT (
  SELECT COUNT(*)
  FROM `project_id.dataset_id.loss_rate_raw` AS l
  JOIN `project_id.dataset_id.product_clean` AS p
    ON TRIM(CAST(l.`Item Code` AS STRING)) = p.item_code
  WHERE TRIM(REPLACE(l.`Item Name`, '\u00a0', ' ')) != p.item_name
) = 0 AS 'noms différents entre loss_rate et product';

-- Les 251 taux ont un espace en fin de valeur : ils arrivent souvent en texte.
-- On retire l'espace puis on convertit en nombre. SAFE_CAST renvoie NULL si la conversion échoue.
ASSERT (
  SELECT COUNT(*) FROM `project_id.dataset_id.loss_rate_raw`
  WHERE SAFE_CAST(TRIM(CAST(`Loss Rate (%)` AS STRING)) AS FLOAT64) IS NULL
     OR SAFE_CAST(TRIM(CAST(`Loss Rate (%)` AS STRING)) AS FLOAT64) NOT BETWEEN 0 AND 100
) = 0 AS 'taux de perte non numérique ou hors de 0 à 100';

CREATE OR REPLACE TABLE `project_id.dataset_id.loss_rate_clean` AS
WITH typed AS (
  SELECT
    TRIM(CAST(`Item Code` AS STRING)) AS item_code,
    CAST(TRIM(CAST(`Loss Rate (%)` AS STRING)) AS FLOAT64) AS loss_rate_pct
  FROM `project_id.dataset_id.loss_rate_raw`
)
SELECT
  p.item_code,
  -- Item Name supprimé : le nom vit dans product
  t.loss_rate_pct,
  -- Taux en décimal, directement utilisable dans les calculs (9,43 % devient 0,0943)
  ROUND(t.loss_rate_pct / 100, 4) AS loss_rate,
  -- 0 % crédible pour un produit emballé, pas pour du frais vendu au kilo
  (t.loss_rate_pct = 0 AND p.packaging = 'kg') AS loss_rate_to_check
FROM typed AS t
JOIN `project_id.dataset_id.product_clean` AS p
  ON t.item_code = p.item_code;
