-- Vytvorenie databázy
CREATE DATABASE GRIZZLY_MovieLens;


-- Vytvorenie schémy pre staging tabuľky
CREATE SCHEMA GRIZZLY_MovieLens.staging;


USE SCHEMA GRIZZLY_MovieLens.staging;


-- Vytvorenie tabuľky age group (staging)
CREATE TABLE age_group_staging (
    age_group_id INT PRIMARY KEY,
    name VARCHAR(45)
);


-- Vytvorenie tabuľky occupation (staging)
CREATE TABLE occupation_staging (
    occupation_id INT PRIMARY KEY,
    name VARCHAR(255)
);


-- Vytvorenie tabuľky users (staging)
CREATE TABLE users_staging (
    user_id INT PRIMARY KEY,
    age INT,
    gender CHAR(1),
    occupation_id INT,
    zip_code VARCHAR(255),
    FOREIGN KEY (age) REFERENCES age_group_staging(age_group_id),
    FOREIGN KEY (occupation_id) REFERENCES occupation_staging(occupation_id)
);


-- Vytvorenie tabuľky movies (staging)
CREATE TABLE movies_staging (
    movie_id INT PRIMARY KEY,
    title VARCHAR(255),
    release_year CHAR(4)
);


-- Vytvorenie tabuľky tags (staging)
CREATE TABLE tags_staging (
    tag_id INT PRIMARY KEY,
    user_id INT,
    movie_id INT,
    tags VARCHAR(4000),
    created_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users_staging(user_id),
    FOREIGN KEY (movie_id) REFERENCES movies_staging(movie_id)
);


-- Vytvorenie tabuľky genres (staging)
CREATE TABLE genres_staging (
    genre_id INT PRIMARY KEY,
    name VARCHAR(255)
);


-- Vytvorenie tabuľky genres movies (staging)
CREATE TABLE genres_movies_staging (
    genres_movies_id INT PRIMARY KEY,
    movie_id INT,
    genre_id INT,
    FOREIGN KEY (genre_id) REFERENCES genres_staging(genre_id),
    FOREIGN KEY (movie_id) REFERENCES movies_staging(movie_id)
);


-- Vytvorenie tabuľky ratings (staging)
CREATE TABLE ratings_staging (
    rating_id INT PRIMARY KEY,
    user_id INT,
    movie_id INT,
    rating INT,
    rated_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users_staging(user_id),
    FOREIGN KEY (movie_id) REFERENCES movies_staging(movie_id)
);


-- Vytvorenie grizzly_stage pre .csv súbory
CREATE OR REPLACE STAGE grizzly_stage;


COPY INTO occupation_staging
FROM @grizzly_stage/occupations.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO age_group_staging
FROM @grizzly_stage/age_group.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO users_staging
FROM @grizzly_stage/users.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO movies_staging
FROM @grizzly_stage/movies.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO tags_staging
FROM @grizzly_stage/tags.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO genres_staging
FROM @grizzly_stage/genres.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO genres_movies_staging
FROM @grizzly_stage/genres_movies.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO ratings_staging
FROM @grizzly_stage/ratings.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);


-- ELT transformácie

-- dimenzia pre dátum
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


-- dimenzia pre tagy
CREATE TABLE dim_tags AS
SELECT DISTINCT 
    t.tag_id,
    us.user_id,
    ms.movie_id,
    t.tags AS tag_name
FROM tags_staging t
LEFT JOIN users_staging us ON t.user_id = us.user_id
LEFT JOIN movies_staging ms ON t.movie_id = ms.movie_id;


-- dimenzia pre userov
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


-- dimenzia pre filmy
CREATE TABLE dim_movies AS
SELECT DISTINCT
    movie_id,
    title,
    release_year
FROM movies_staging;


-- dimenzia pre žánre
CREATE TABLE dim_genres AS
SELECT DISTINCT
    genre_id,
    name AS genre_name
FROM genres_staging;


-- factová tabuľka pre ratings
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


-- Dropnutie staging tabuliek
DROP TABLE IF EXISTS age_group_staging;
DROP TABLE IF EXISTS occupation_staging;
DROP TABLE IF EXISTS users_staging;
DROP TABLE IF EXISTS movies_staging;
DROP TABLE IF EXISTS tags_staging;
DROP TABLE IF EXISTS genres_staging;
DROP TABLE IF EXISTS genres_movies_staging;
DROP TABLE IF EXISTS ratings_staging;
