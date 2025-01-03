
USE SCHEMA GRIZZLY_MovieLens.staging;

-- 1. Graf: Vývoj Obľúbenosti Žánrov v Čase
SELECT 
    dg.genre_name, 
    dd.year, 
    COUNT(fr.rating) AS total_ratings
FROM fact_ratings fr
JOIN dim_genres dg ON fr.genre_id = dg.genre_id
JOIN dim_date dd ON fr.date_id = dd.iddim_date
GROUP BY dg.genre_name, dd.year
ORDER BY dd.year, total_ratings DESC;

-- 2. Graf: Analýza Tagov Podľa Žánru
SELECT 
    dg.genre_name, 
    dt.tag_name, 
    COUNT(*) AS total_tags
FROM dim_tags dt
JOIN fact_ratings fr ON dt.tag_id = fr.tag_id
JOIN dim_genres dg ON fr.genre_id = dg.genre_id
GROUP BY dg.genre_name, dt.tag_name
HAVING COUNT(*) > 5
ORDER BY dg.genre_name, total_tags DESC;

-- 3. Graf: Porovnanie pohlavia a obľúbenosť žánrov
SELECT 
    du.gender, 
    dg.genre_name, 
    COUNT(fr.rating) AS total_ratings
FROM fact_ratings fr
JOIN dim_users du ON fr.user_id = du.user_id
JOIN dim_genres dg ON fr.genre_id = dg.genre_id
GROUP BY du.gender, dg.genre_name
ORDER BY du.gender, total_ratings DESC;

-- 4. Graf: Hodnotenia podľa Dňa v Týždni
SELECT 
    DATE_PART('WEEKDAY', dd.rated_at) AS weekday, 
    COUNT(fr.rating) AS total_ratings
FROM fact_ratings fr
JOIN dim_date dd ON fr.date_id = dd.iddim_date
GROUP BY DATE_PART('WEEKDAY', dd.rated_at)
ORDER BY weekday;

-- 5. Graf: Top 5 Používateľov s Najvyšším Počtom Hodnotení
SELECT 
    du.user_id, 
    du.age_group, 
    du.gender, 
    COUNT(fr.rating) AS total_ratings
FROM fact_ratings fr
JOIN dim_users du ON fr.user_id = du.user_id
GROUP BY du.user_id, du.age_group, du.gender
ORDER BY total_ratings DESC
LIMIT 5;

-- 6. Graf: Predikcia Obľúbenosti Žánrov
SELECT 
    dg.genre_name, 
    DATE_PART('MONTH', dd.rated_at) AS month, 
    COUNT(fr.rating) AS total_ratings
FROM fact_ratings fr
JOIN dim_genres dg ON fr.genre_id = dg.genre_id
JOIN dim_date dd ON fr.date_id = dd.iddim_date
GROUP BY dg.genre_name, DATE_PART('MONTH', dd.rated_at)
ORDER BY dg.genre_name, month;