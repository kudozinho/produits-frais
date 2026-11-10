-- Ibrahim : nettoyage de loss_rate.csv

CREATE OR REPLACE TABLE loss_rate_clean AS
SELECT
    "Item Code" AS item_code,                               -- Item Name n'est pas repris : il est déjà dans product
    CAST(trim("Loss Rate (%)") AS DOUBLE) AS taux_perte     -- lu comme du texte à cause d'un espace après chaque valeur
FROM read_csv('data/loss_rate.csv', types = {'Item Code': 'VARCHAR'});
