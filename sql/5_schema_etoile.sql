-- Schéma en étoile : 1 table de faits + 2 dimensions

-- Dimension produit : product + loss_rate (1 pour 1) + unité de vente
CREATE OR REPLACE TABLE dim_product AS
SELECT
    p.item_code,
    p.item_name,
    p.category_code,
    p.category_name,
    l.taux_perte,
    -- si toutes les quantités vendues sont des nombres entiers, le produit est vendu à l'unité (sachet, boîte)
    CASE
        WHEN p.item_code IN (
            SELECT item_code FROM transaction_clean
            GROUP BY item_code
            HAVING bool_and(quantite = round(quantite))
        ) THEN 'unité'
        ELSE 'kg'
    END AS unite_vente
FROM product_clean AS p
LEFT JOIN loss_rate_clean AS l ON p.item_code = l.item_code;

-- Dimension date : un jour par ligne, avec la période N ou N-1
CREATE OR REPLACE TABLE dim_date AS
SELECT DISTINCT
    date,
    year(date) AS annee,
    month(date) AS mois,
    strftime(date, '%Y-%m') AS annee_mois,
    CASE
        WHEN date BETWEEN '2022-07-01' AND '2023-06-30' THEN 'N'
        WHEN date BETWEEN '2021-07-01' AND '2022-06-30' THEN 'N-1'
        ELSE 'avant'
    END AS periode
FROM transaction_clean
ORDER BY date;

-- Table de faits : une ligne par vente, avec le prix d'achat du jour
CREATE OR REPLACE TABLE fact_sales AS
SELECT
    t.date,
    t.heure,
    t.item_code,
    t.quantite,
    t.prix_vente,
    p.prix_achat,
    t.remise,
    t.quantite * t.prix_vente AS ca,
    t.quantite * (t.prix_vente - p.prix_achat) AS marge_brute,
    t.achat_atypique
FROM transaction_clean AS t
LEFT JOIN price_clean AS p ON t.date = p.date AND t.item_code = p.item_code;

-- Export des 3 tables pour le dashboard
COPY fact_sales TO 'data/fact_sales.csv' (HEADER);
COPY dim_product TO 'data/dim_product.csv' (HEADER);
COPY dim_date TO 'data/dim_date.csv' (HEADER);
