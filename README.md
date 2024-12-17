
# **ETL Proces pre MovieLens Dataset**

Tento repozitár obsahuje implementáciu ETL procesu v Snowflake na analýzu dát z MovieLens datasetu. Projekt sa zameriava na analýzu správania používateľov a ich preferencií filmov na základe hodnotení a demografických údajov. Výsledný dátový model umožňuje detailnú analýzu a vizualizáciu hlavných metrík. 🎥

---
## **1. Úvod a charakteristika zdrojových dát**

Hlavným cieľom tohto projektu je analyzovať údaje o filmoch, používateľoch a ich hodnoteniach. Táto analýza pomáha odhaliť:
- Trendy vo filmových preferenciách 🎥.
- Najobľúbenejšie filmy 🎦.
- Správanie rôznych skupín používateľov 🔐.

**Zdrojové dáta:**
Dáta pochádzajú z verejne dostupného MovieLens datasetu, ktorý obsahuje päť hlavných tabuliek:
- `movies` (detaily o filmoch)
- `ratings` (hodnotenia filmov)
- `users` (informácie o používateľoch)
- `genres` (kategórie žánrov)
- `tags` (dodatočné štítky filmov)

ETL proces bol navrhnutý tak, aby pripravil, transformoval a sprístupnil tieto dáta pre viacdimenzionálnu analýzu 🌐.

---
### **1.1 Architektúra dát**

#### **Entitno-relačný diagram (ERD)**
Zdrojové dáta sú usporiadané v relačnom modeli znázornenom v nasledujúcom ERD diagrame. Tento diagram ukazuje, ako sú jednotlivé tabuľky prepojené.

<p align="center">
  <img src="https://github.com/martinrosik/MovieLens-ETL/blob/master/MovieLens_ERD.png" alt="ERD Schema">
  <br>
  <em>Obrázok 1: Entitno-relačná schéma MovieLens datasetu</em>
</p>

---
## **2. Dimenzionálny model**

Pre účely analýzy bol navrhnutý **hviezdicový model (star schema)**. Tento model obsahuje centálnu faktovú tabuľku `fact_ratings`, ktorá uchováva hodnotenia filmov, a niekoľko dimenzií:

- **`dim_movies`**: Informácie o filmoch (názov, rok vydania, žánre). 🎥
- **`dim_users`**: Demografické údaje o používateľoch (vek, pohlavie, lokalita). 👨‍👩‍👦
- **`dim_date`**: Informácie o dátumoch hodnotení (deň, mesiac, rok, štvrťrok). 🕧
- **`dim_genres`**: Kategórie žánrov pre analýzu preferencií. 🎶
- **`dim_tags`**: Štítky pre filmy a hodnotenia. 🌂

#### **Star Schema**
Hviezdicový model zobrazuje jasné vzťahy medzi dimenziami a faktovou tabuľkou:

<p align="center">
  <img src="https://github.com/martinrosik/MovieLens-ETL/blob/master/MovieLens_star-scheme.png" alt="Star Schema">
  <br>
  <em>Obrázok 2: Schéma hviezdy pre MovieLens dataset</em>
</p>

---
## **3. ETL proces v Snowflake**

ETL proces pozostával z troch hlavných fáz: **Extract, Transform a Load**. Snowflake bol využitý ako robustná platforma pre spracovanie dát ⚡️.

### **3.1 Extrahovanie dát**

Dáta boli nahrané z `CSV` súborov do Snowflake pomocou interného **stage** úložiska.

#### Príklad kódu:
```sql
CREATE OR REPLACE STAGE movielens_stage;
```

```sql
COPY INTO movies_staging
FROM @movielens_stage/movies.csv
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1);
```
Chybné záznamy boli ignorované pomocou parametra `ON_ERROR = 'CONTINUE'`. 🚫

---
### **3.2 Transformácia dát**

Dáta boli vyčistené, transformované a pripravené na analyzáciu vo finálnom dátovom modeli.

#### Transformácie:
1. **Dimenzia `dim_users`:**
   Rozdelenie veku používateľov do kategórií:
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

2. **Dimenzia `dim_date`:**
   Extrakcia detailných údajov o časových aspektoch:
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

3. **Faktová tabuľka `fact_ratings`:**
   Kombinácia hlavných metrík:
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

Po úspešnom spracovaní boli staging tabuľky odstránené pre optimalizáciu:

```sql
DROP TABLE IF EXISTS movies_staging;
DROP TABLE IF EXISTS users_staging;
DROP TABLE IF EXISTS ratings_staging;
```

---
## **4. Vizualizácia dát**

Dashboard obsahuje 6 vizualizácií, ktoré poskytujú základný prehľad o kľúčových metrikách a trendoch týkajúcich sa filmov, používateľov a hodnotení. Tieto vizualizácie odpovedajú na dôležité otázky a umožňujú lepšie pochopiť správanie používateľov a ich preferencie 🔦:

<p align="center">
  <img src="" alt="Data visualization">
  <br>
  <em>Obrázok 3: Dashboard MovieLens datasetu</em>
</p>

1. **Top 10 hodnotených filmov**:
   Vizualizácia najčastejšie hodnotených filmov:
   ```sql
   SELECT
    m.title AS movie_title,
    COUNT(f.fact_ratingID) AS total_ratings
    FROM fact_ratings f
    JOIN dim_movies m ON f.movieID = m.dim_movieId
    GROUP BY m.title
    ORDER BY total_ratings DESC
    LIMIT 10;
   ```

2. **Rozdelenie hodnotení podľa pohlavia:**
   Porovnanie počtu hodnotení od mužov a žien.
   ```sql
   SELECT
    u.gender,
    COUNT(f.fact_ratingID) AS total_ratings
    FROM fact_ratings f
    JOIN dim_users u ON f.userID = u.dim_userId
    GROUP BY u.gender;
   ```

3. **Priemerné hodnotenia filmov podľa rokov vydania:**
   Odhalenie trendov v hodnoteniach filmov v rôznych obdobiach.
   ```sql
    SELECT
    m.release_year,
    ROUND(AVG(f.rating), 2) AS average_rating
    FROM fact_ratings f
    JOIN dim_movies m ON f.movieID = m.dim_movieId
    GROUP BY m.release_year
    ORDER BY m.release_year;
   ```

4. **Aktivita podľa dňí v týždni:**
   Zobrazenie najaktívnejších časov hodnotenia.
   ```sql
   SELECT
    DAYNAME(f.rating_timestamp) AS day_of_week,
    COUNT(f.fact_ratingID) AS total_ratings
    FROM fact_ratings f
    GROUP BY day_of_week
    ORDER BY total_ratings DESC;
   ```

5. **Najčastejšie hodnotené žánre:**
   Preferencie používateľov podľa filmových žánrov.
   ```sql
   SELECT
    g.genre,
    COUNT(f.fact_ratingID) AS total_ratings
    FROM fact_ratings f
    JOIN dim_movies m ON f.movieID = m.dim_movieId
    JOIN dim_genres g ON m.dim_movieId = g.movieID
    GROUP BY g.genre
    ORDER BY total_ratings DESC;
   ```

6. **Aktivita podľa vekových skupín:**
   Porovnanie časov hodnotenia jednotlivých vekových skupín.
   ```sql
   SELECT
    u.age_group,
    COUNT(f.fact_ratingID) AS total_ratings
    FROM fact_ratings f
    JOIN dim_users u ON f.userID = u.dim_userId
    GROUP BY u.age_group
    ORDER BY total_ratings DESC;
   ```

---
## **5. Záver**

ETL proces pre MovieLens dataset umožnil transformáciu zdrojových dát do robustného dátového modelu, ktorý podporuje analýzu správania používateľov a filmových preferencií.

### **Možné aplikácie:**
- Odporúcacie systémy 🔍.
- Marketingové kampane 🌐.
- Detailná analýza trendov 🌟.


**Autor**: Martin Rosík
