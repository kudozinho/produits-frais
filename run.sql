-- Lance tout le nettoyage dans l'ordre.
-- Commande, depuis le dossier du projet : duckdb -c ".read run.sql"

.read sql/1_transaction.sql
.read sql/2_price.sql
.read sql/3_product.sql
.read sql/4_loss_rate.sql
.read sql/5_schema_etoile.sql

-- Vérification : CA et marge brute N vs N-1 (on doit retrouver +24,1 % de CA comme dans l'exercice 1)
SELECT
    d.periode,
    round(sum(f.ca)) AS ca,
    round(sum(f.marge_brute)) AS marge_brute
FROM fact_sales AS f
INNER JOIN dim_date AS d ON f.date = d.date
WHERE d.periode IN ('N', 'N-1')
GROUP BY d.periode
ORDER BY d.periode;
