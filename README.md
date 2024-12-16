# **ETL proces pre MovieLens Dataset**

Tento repozitár obsahuje implementáciu ETL procesu v Snowflake pre analýzu dát z MovieLens datasetu. Projekt sa sústreďuje na skúmanie správania používateľov a ich preferencií filmov na základe hodnotení a demografických údajov. Výsledný dátový model umožňuje detailnú analýzu a vizualizáciu hlavných metrík.

---
## **1. Úvod a charakteristika zdrojových dát**
Hlavným cieľom tohto projektu je analyzovať údaje o filmoch, používateľoch a ich hodnoteniach. Takáto analýza odhaľuje trendy vo filmových preferenciách, najobľúbenejšie filmy a správanie rôznych skupín používateľov.

Zdrojové dáta pochádzajú z verejne dostupného datasetu MovieLens. Tento dataset obsahuje päť hlavných tabuliek:
- `movies`
- `ratings`
- `users`
- `genres`
- `tags`

ETL proces bol navrhnutý tak, aby pripravil, transformoval a sprístupnil tieto dáta pre viacdimenzionálnu analýzu.

---
### **1.1 Architektúra dát**
ERD schéma
Dáta sú uložené v relačnom modeli, ktorý je vizualizovaný prostredníctvom entitno-relačného diagramu (ERD).

### **ERD schéma**
Surové dáta sú usporiadané v relačnom modeli, ktorý je znázornený na **entitno-relačnom diagrame (ERD)**:

<p align="center">
  <img src="https://github.com/martinrosik/MovieLens-ETL/blob/master/MovieLens_ERD.png" alt="ERD Schema">
  <br>
  <em>Obrázok 1: Entitno-relačná schéma MovieLens datasetu</em>
</p>

---
## **2 Dimenzionálny model**

Navrhnutý **hviezdicový model (star schema)** zahŕňa centrálnu faktovú tabuľku, ktorá uchováva hodnotenia filmov a ich prepojenie na rôzne dimenzie:

-**`dim_movies`**: Informácie o filmoch (názov, rok vydania, žánre).
-**`dim_users`**: Demografické údaje o používateľoch (vek, pohlavie, lokalita).
-**`dim_date`**: Informácie o dátumoch hodnotení (deň, mesiac, rok, štvrťrok).
-**`dim_genres`**: Kategórie žánrov pre analýzu preferencií.
-**`dim_tags`**: Tags

Star Schema
<p align="center">
  <img src="https://github.com/martinrosik/MovieLens-ETL/blob/master/MovieLens_star-scheme.png" alt="Star Schema">
  <br>
  <em>Obrázok 2: Schéma hviezdy pre MovieLens dataset</em>
</p>

---
## **3. ETL proces v Snowflake**
Proces pozostával z troch fáz: Extract, Transform a Load, pričom Snowflake bol využitý ako platforma pre spracovanie dát.

---
### **3.1 Extrahovanie dát**
Dáta z `CSV` súborov boli nahrané do Snowflake pomocou interného stage úložiska:

#### Príklad kódu:
```sql
CREATE OR REPLACE STAGE movielens_stage;
```

```sql
COPY INTO movies_staging
FROM @movielens_stage/movies.csv
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1);
```

Chybné záznamy boli ignorované pomocou parametra `ON_ERROR = 'CONTINUE'`.

---
### **3.2 Transformácia dát**
V tejto fáze boli dáta vyčistené, transformované a pripravené na použitie vo finálnom dátovom modeli.

Dimenzia `dim_users` obsahuje demografické údaje, pričom vek bol rozdelený do kategórií:

```sql
CREATE TABLE dim_users AS
SELECT DISTINCT
    userId AS dim_userId,
    CASE 
        WHEN age < 18 THEN 'Under 18'
        WHEN age BETWEEN 18 AND 24 THEN '18-24'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age >= 45 THEN '45+'
        ELSE 'Unknown'
    END AS age_group,
    gender,
    location
FROM users_staging;
```
Dimenzia `dim_date` zabezpečuje podrobné časové údaje, ako sú dni v týždni či štvrťroky:

```sql
CREATE TABLE dim_date AS
SELECT
    ROW_NUMBER() OVER (ORDER BY CAST(timestamp AS DATE)) AS dim_dateID,
    CAST(timestamp AS DATE) AS date,
    DATE_PART(day, timestamp) AS day,
    DATE_PART(dow, timestamp) AS dayOfWeek,
    DATE_PART(month, timestamp) AS month,
    DATE_PART(year, timestamp) AS year,
    DATE_PART(quarter, timestamp) AS quarter
FROM ratings_staging;
```
Faktová tabuľka `fact_ratings` kombinuje kľúčové metriky:

```sql
CREATE TABLE fact_ratings AS
SELECT 
    r.ratingId AS fact_ratingID,
    r.timestamp AS timestamp,
    r.rating,
    d.dim_dateID AS dateID,
    m.dim_movieId AS movieID,
    u.dim_userId AS userID
FROM ratings_staging r
JOIN dim_date d ON CAST(r.timestamp AS DATE) = d.date
JOIN dim_movies m ON r.movieId = m.dim_movieId
JOIN dim_users u ON r.userId = u.dim_userId;
```

---
### **3.3 Načítanie dát**
Po úspešnom spracovaní boli staging tabuľky odstránené:

```sql
DROP TABLE IF EXISTS movies_staging;
DROP TABLE IF EXISTS users_staging;
DROP TABLE IF EXISTS ratings_staging;
```

---
## **4. Vizualizácia dát**
Dashboard poskytuje prehľadné vizualizácie kľúčových metrík:

Top 10 hodnotených filmov
Vizualizácia zobrazuje najčastejšie hodnotené filmy:

sql
Kopírovať kód
SELECT 
    m.title AS movie_title,
    COUNT(f.fact_ratingID) AS total_ratings
FROM fact_ratings f
JOIN dim_movies m ON f.movieID = m.dim_movieId
GROUP BY m.title
ORDER BY total_ratings DESC
LIMIT 10;
Rozdelenie hodnotení podľa pohlavia
Analýza porovnáva počet hodnotení od mužov a žien.

Priemerné hodnotenia filmov podľa rokov vydania
Tento graf odhaľuje trendy v hodnoteniach filmov v rôznych obdobiach.

Aktivita počas dní v týždni
Ukazuje, kedy sú používatelia najaktívnejší.

Najčastejšie hodnotené žánre
Vizualizácia odhaľuje preferencie používateľov podľa žánrov.

Aktivita podľa vekových skupín
Graf porovnáva, kedy sú jednotlivé vekové skupiny najaktívnejšie.

ETL proces pre MovieLens umožnil transformáciu zdrojových dát do robustného dátového modelu, ktorý podporuje analýzu správania používateľov a filmových preferencií. Výstupy môžu byť využité pre odporúčacie systémy, marketingové kampane a ďalšie analytické účely.
