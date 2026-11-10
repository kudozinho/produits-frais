-- Henriquet : nettoyage de transaction.csv

CREATE OR REPLACE TABLE transaction_clean AS
SELECT
    "Date" AS date,
    "Time" AS heure,
    "Item Code" AS item_code,                         -- lu en texte (voir read_csv) : c'est un code, pas un nombre
    "Quantity Sold (kilo)" AS quantite,
    "Unit Selling Price (RMB/kg)" AS prix_vente,
    "Discount (Yes/No)" AS remise,
    "Quantity Sold (kilo)" >= 20 AS achat_atypique    -- ex : 160 sachets le 2022-06-09, signalé mais gardé
FROM read_csv('data/transaction.csv', types = {'Item Code': 'VARCHAR'})
WHERE "Sale or Return" = 'sale';                      -- on retire les 461 retours
