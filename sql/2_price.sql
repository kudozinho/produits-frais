-- Henriquet : nettoyage de price.csv

CREATE OR REPLACE TABLE price_clean AS
SELECT
    "Date" AS date,
    "Item Code" AS item_code,
    "Wholesale Price (RMB/kg)" AS prix_achat
FROM read_csv('data/price.csv', types = {'Item Code': 'VARCHAR'});
