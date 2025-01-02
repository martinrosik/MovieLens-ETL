
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
CREATE OR REPLACE STAGE grizzly_stage;
```

```sql
COPY INTO occupation_staging
FROM @grizzly_stage/occupations.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
```

---
### **3.2 Transformácia dát**

Dáta boli vyčistené, transformované a pripravené na analyzáciu vo finálnom dátovom modeli.

#### Transformácie:
1. **Dimenzia `dim_users`:**
   Rozdelenie veku používateľov do kategórií:
   ```sql
   CREATE OR REPLACE TABLE dim_users AS
    SELECT DISTINCT 
      us.user_id,
      os.name AS occupation,
      us.gender,
      us.age,
      ag.name AS age_group
    FROM users_staging us
    LEFT JOIN occupation_staging os ON us.occupation_id = us.occupation_id
    LEFT JOIN age_group_staging ag
    ON (
        (ag.name = 'Under 18' AND us.age < 18) OR
        (ag.name = '18-24' AND us.age BETWEEN 18 AND 24) OR
        (ag.name = '25-34' AND us.age BETWEEN 25 AND 34) OR
        (ag.name = '35-44' AND us.age BETWEEN 35 AND 44) OR
        (ag.name = '45-49' AND us.age BETWEEN 45 AND 49) OR
        (ag.name = '50-55' AND us.age BETWEEN 50 AND 55) OR
        (ag.name = '56+' AND us.age >= 56))
    ORDER BY us.user_id;
   ```

2. **Dimenzia `dim_date`:**
   Extrakcia detailných údajov o časových aspektoch:
   ```sql
   CREATE TABLE dim_date AS
    SELECT
      ROW_NUMBER() OVER (ORDER BY CAST(rated_at AS DATE)) AS iddim_date, 
      rated_at,
      DATE_PART(day, rated_at) AS day, 
      DATE_PART(week, rated_at) AS week,
      DATE_PART(month, rated_at) AS month,              
      DATE_PART(year, rated_at) AS year,                               
      DATE_PART(quarter, rated_at) AS quartal        
    FROM ratings_staging
    GROUP BY rated_at,
         DATE_PART(day, rated_at),
         DATE_PART(week, rated_at),
         DATE_PART(month, rated_at), 
         DATE_PART(year, rated_at),  
         DATE_PART(quarter, rated_at);
   ```
3. **Dimenzia `dim_tags`:**
   Pripravené údaje o značkách:
   ```sql
   CREATE TABLE dim_tags AS
    SELECT DISTINCT 
      t.tag_id,
      us.user_id,
      ms.movie_id,
      t.tags AS tag_name
    FROM tags_staging t
    LEFT JOIN users_staging us ON t.user_id = us.user_id
    LEFT JOIN movies_staging ms ON t.movie_id = ms.movie_id;
    ```

5. **Dimenzia `dim_movies`:**
   Transformácia filmových údajov:
   ```sql
   CREATE TABLE dim_movies AS
    SELECT DISTINCT
      movie_id,
      title,
      release_year
    FROM movies_staging;
    ```

7. **Dimenzia `dim_genres`:**
   Pripravené údaje o žánroch:
   ```sql
    CREATE TABLE dim_genres AS
    SELECT DISTINCT
      genre_id,
      name AS genre_name
    FROM genres_staging;
   ```

9. **Faktová tabuľka `fact_ratings`:**
   Kombinácia hlavných metrík:
   ```sql
   CREATE OR REPLACE TABLE fact_ratings AS
    SELECT DISTINCT
      rs.rating_id AS rating_id,        
      rs.rated_at AS rated_at,   
      rs.rating,                          
      dm.movie_id AS movie_id,
      dt.tag_id AS tag_id,
      dd.iddim_date AS date_id,
      du.user_id AS user_id,
      dg.genre_id AS genre_id
    FROM ratings_staging rs
    LEFT JOIN dim_date dd ON rs.rated_at = dd.rated_at
    LEFT JOIN dim_movies dm ON rs.movie_id = dm.movie_id         
    LEFT JOIN dim_users du ON rs.user_id = du.user_id
    LEFT JOIN dim_tags dt ON rs.movie_id = dt.movie_id
    LEFT JOIN genres_movies_staging gms ON rs.movie_id = gms.movie_id
    LEFT JOIN dim_genres dg ON gms.genre_id = dg.genre_id;
   ```

---
### **3.3 Načítanie dát**

Po úspešnom spracovaní boli staging tabuľky odstránené pre optimalizáciu:

```sql
DROP TABLE IF EXISTS age_group_staging;
DROP TABLE IF EXISTS occupation_staging;
DROP TABLE IF EXISTS users_staging;
DROP TABLE IF EXISTS movies_staging;
DROP TABLE IF EXISTS tags_staging;
DROP TABLE IF EXISTS genres_staging;
DROP TABLE IF EXISTS genres_movies_staging;
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
