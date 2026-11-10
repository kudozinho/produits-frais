# Ventes de produits frais : nettoyage des données

Exercice 2, Data Analytics, Eugenia School. Binôme : **Henriquet** et **Ibrahim**.

Objectif : nettoyer les 4 fichiers reçus (`transaction.csv`, `product.csv`, `price.csv`, `loss_rate.csv`) pour alimenter un dashboard avec 3 KPI : **CA, marge brute, quantité vendue**, et leur évolution vs N-1.

- Période N : juillet 2022 à juin 2023
- Période N-1 : juillet 2021 à juin 2022

| Qui | Fichiers |
|---|---|
| Henriquet | `transaction.csv`, `price.csv` |
| Ibrahim | `product.csv`, `loss_rate.csv` |

---

## Étape 1 : diagnostic des fichiers

Dans les 4 fichiers : **aucune valeur manquante et aucun doublon exact**.

### transaction.csv (Henriquet) :

| Problème trouvé | Ce qu'on fait | Pourquoi (logique métier) |
|---|---|---|
| `Item Code` est lu comme un nombre | On le lit en texte | C'est un code produit, pas une valeur à additionner |
| 461 retours, avec une quantité négative | On les retire | Le CA et la quantité vendue se calculent sans les retours |
| Une vente de 160 le 2022-06-09 : ce sont 160 sachets de Xianzongye, d'habitude vendu par 1 | On la garde, avec une colonne `achat_atypique` (quantité de 20 ou plus) | On ne sait pas si c'est une erreur ou une grosse commande : on la signale sans la supprimer |
| Doublon probable le 2021-10-16 à 16:40:22.748 : même produit, même milliseconde, mais 0,565 kg et 0,578 kg | On garde les 2 lignes | Les poids sont différents, ce n'est pas un doublon exact (impact : 4,62 RMB) |
| Certains produits sont vendus au sachet ou à la boîte alors que la colonne dit "kilo" | Colonne `unite_vente` (kg ou unité) dans `dim_product` | Additionner des kilos et des sachets fausserait la quantité vendue |

### price.csv (Henriquet) :

| Problème trouvé | Ce qu'on fait | Pourquoi (logique métier) |
|---|---|---|
| `Item Code` est lu comme un nombre | On le lit en texte | C'est la clé de jointure avec les ventes |
| Rien d'anormal : un seul prix par jour et par produit, et chaque vente trouve son prix | On renomme seulement les colonnes | Ce prix d'achat sert à calculer la marge brute |

### product.csv (Ibrahim) : 

251 produits, 4 colonnes.

| Problème trouvé | Ce qu'on fait | Pourquoi (logique métier) |
|---|---|---|
| `Item Code` sur 15 chiffres, lu comme un nombre | On le passe en texte, on contrôle 15 chiffres et l'unicité | Excel le met en notation scientifique et casse les jointures avec transaction et price |
| Un espace invisible (insécable) dans la catégorie "Flower/Leaf Vegetables", sur ses 100 lignes | On le remplace par un espace normal | Sinon un filtre sur la plus grosse catégorie ne trouve rien |
| 4 noms avec un espace en trop à la fin (Foreign Garland Chrysanthemum, Yuxingcao, Powcan Mountain Chinese Cabbage, Hericium) | On retire l'espace | Sinon le même produit apparaît 2 fois dans un filtre |
| `Category Code` lu comme un nombre | On le passe en texte | C'est un identifiant, on ne calcule jamais dessus |
| 4 noms en double sous 2 codes différents (Broccoli, Chinese Cabbage, Apricot Bao Mushroom (Bag), Chinese Caterpillar Fungus Flowers (Bag)) | On garde les 2, signalés par `is_duplicate_name` | Ce sont 2 produits différents (Broccoli existe même dans 2 catégories) : on analyse toujours par `Item Code` |
| Le conditionnement est caché dans le nom : 65 en sachet, 15 en boîte, 3 en botte, 1 à la pièce | Nouvelle colonne `packaging` | La quantité est en kilo dans transaction : pour ces produits, l'unité réelle est douteuse (ex : 160 kg vendus d'un produit en sachet) |
| Colonnes avec espaces et majuscules | Renommées en snake_case | Des noms stables et lisibles en SQL et dans le dashboard |

Contrôles qui passent : aucune valeur manquante, aucun doublon, chaque code catégorie a un seul nom (6 catégories).

### loss_rate.csv (Ibrahim) :

251 produits, 3 colonnes.

| Problème trouvé | Ce qu'on fait | Pourquoi (logique métier) |
|---|---|---|
| Le taux de perte est lu comme du texte (un espace après chaque valeur, ex : "4.39 ") | On retire l'espace et on le convertit en nombre | Pour pouvoir calculer et filtrer avec |
| Fichier encodé en UTF-8 avec BOM | On vérifie à l'import que la 1re colonne s'appelle bien `Item Code` | Sinon un caractère invisible se colle au nom de colonne et la requête plante |
| `Item Code` sur 15 chiffres | On le passe en texte, on contrôle l'unicité | Même raison que product : c'est la clé de jointure |
| Les mêmes 251 codes que product | Contrôle bloquant | Relation 1 pour 1 : chaque produit a exactement un taux de perte |
| `Item Name` est déjà dans product, avec les mêmes valeurs | On vérifie puis on ne garde pas cette colonne | Un seul endroit pour le nom du produit |
| Taux en pourcentage (9,43) | Contrôle entre 0 et 100, ajout du taux en décimal (0,0943) | Le décimal se multiplie directement pour calculer le coût des pertes |
| 22 produits à 0 % de perte : 13 emballés, 9 vendus au kilo | On les garde, les 9 au kilo sont signalés par `loss_rate_to_check` | 0 % est crédible pour un produit en boîte ou en sachet, pas pour un légume frais en vrac (Lameizi, Lotus Root Tip...). On signale sans inventer de valeur |
| 85 produits à 9,43 % (la moyenne de la colonne) | On les garde | À vérifier avec le métier : ce sont sûrement des valeurs par défaut |
| Taux maximum 29,25 % (High Melon (1)) | On le garde | Élevé mais plausible pour un produit très périssable |

---

## Étape 2 : modèle de données

### Modèle relationnel

![Modèle relationnel](images/modele_relationnel.png)

- `product` est au centre : chaque fichier s'y relie par `Item Code`
- `transaction` se relie à `price` par `Date` + `Item Code` (le prix d'achat du jour)
- `loss_rate` a exactement un taux par produit (relation 1 pour 1)

### Schéma en étoile

![Schéma en étoile](images/schema_etoile.png)

| Table | Contenu | Construite avec |
|---|---|---|
| `fact_sales` | 1 ligne = 1 vente, avec CA et marge brute | transaction + price |
| `dim_product` | 1 ligne = 1 produit, avec sa catégorie, son taux de perte et son unité de vente | product + loss_rate |
| `dim_date` | 1 ligne = 1 jour, avec la période N ou N-1 | dates des ventes |

---

## Étape 3 : code de nettoyage

Langage : **SQL**, avec DuckDB.

| Fichier | Rôle | Qui |
|---|---|---|
| `sql/1_transaction.sql` | Nettoie transaction.csv | Henriquet |
| `sql/2_price.sql` | Nettoie price.csv | Henriquet |
| `sql/3_product.sql` | Nettoie product.csv | Ibrahim |
| `sql/4_loss_rate.sql` | Nettoie loss_rate.csv | Ibrahim |
| `sql/5_schema_etoile.sql` | Fait les jointures et crée fact_sales, dim_product, dim_date | les deux |
| `run.sql` | Lance les 5 fichiers dans l'ordre | |

**Lancer le projet :**

1. Mettre les 4 CSV dans le dossier `data/`
2. Installer DuckDB (une seule fois) : `winget install DuckDB.cli`
3. Dans le dossier du projet : `duckdb -c ".read run.sql"`

Résultat : `fact_sales.csv`, `dim_product.csv` et `dim_date.csv` dans `data/`, prêts pour le dashboard.

**Vérification :** on retrouve les chiffres de l'exercice 1.

| | N | N-1 | Évolution |
|---|---:|---:|---:|
| CA | 1 155 057 RMB | 930 519 RMB | +24,1 % |
| Marge brute | 447 119 RMB | 333 672 RMB | +34,0 % |

**Version BigQuery de product et loss_rate (Ibrahim) :**

| Fichier | Rôle |
|---|---|
| `sql/clean_product.sql` | Nettoie product.csv, ajoute `packaging` et `is_duplicate_name` |
| `sql/clean_loss_rate.sql` | Nettoie loss_rate.csv, ajoute le taux en décimal et `loss_rate_to_check` |

1. Charger les CSV bruts dans les tables `product_raw` et `loss_rate_raw`
2. Remplacer `project_id.dataset_id` par votre projet et dataset dans les 2 fichiers
3. Lancer `sql/clean_product.sql`, puis `sql/clean_loss_rate.sql` (l'ordre compte : le second lit `product_clean`)

Chaque script contient des `ASSERT` : si un contrôle échoue, la requête s'arrête avec un message clair. Ces 2 fichiers ne sont pas lancés par `run.sql`, qui reste en DuckDB. Dans le schéma en étoile, les deux tables se rejoignent dans `dim_product` par `item_code`.

---

## Organisation Git

- `main` : la version finale
- `develop` : on y fusionne le travail des deux
- Une branche par partie : `feature/clean-transaction` et `feature/clean-price` (Henriquet), `nettoyage-product-loss-rate` (Ibrahim)
- Le dossier `data/` n'est pas sur Git (`.gitignore`) : `transaction.csv` fait 50 Mo
