SELECT
    c.name AS country,
    g.report_date,
    g.confirmed
FROM global_covid_stats g
JOIN country c
    ON g.country_id = c.country_id
WHERE g.report_date = DATE '2021-09-30'
ORDER BY g.confirmed DESC
LIMIT 1;
SELECT
    c.name AS country,
    g.report_date,
    SUM(g.deaths) AS total_deaths
FROM global_covid_stats g
JOIN country c
    ON g.country_id = c.country_id
WHERE g.report_date = DATE '2021-09-30'
GROUP BY c.name, g.report_date
ORDER BY total_deaths DESC;

--3. List the continents along with the total number of confirmed cases, deaths, and recoveries.
SELECT 
    c.continent,
    SUM(cs.confirmed) AS confirmed_cases,
    SUM(cs.deaths) AS deaths,
    SUM(cs.recovered) AS recoveries
FROM country c
JOIN covid_case_stats cs
    ON c.country_id = cs.country_id
GROUP BY c.continent
ORDER BY c.continent;

-- UC4 — Average new deaths per day across all countries
SELECT 
    AVG(daily_deaths) AS average_new_deaths_per_day
FROM (
    SELECT 
        report_date,
        SUM(new_deaths) AS daily_deaths
    FROM covid_case_stats
    GROUP BY report_date
) AS daily_data;


-- UC5 — Maximum active cases in any country on a specific date
SELECT 
    c.name AS country,
    MAX(cs.active_cases) AS maximum_active_cases
FROM country c
JOIN covid_case_stats cs
    ON c.country_id = cs.country_id
WHERE cs.report_date = '2020-01-30'
GROUP BY c.name
ORDER BY maximum_active_cases DESC
LIMIT 1;

-- UC6
CREATE OR REPLACE PROCEDURE get_total_recovered(
    p_country_id INT,
    p_date DATE,
    OUT total_recovered INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT COALESCE(SUM(recovered), 0)
    INTO total_recovered
    FROM covid_case_stats
    WHERE country_id = p_country_id
      AND report_date = p_date;
END;
$$;
CALL get_total_recovered(1, '2020-01-30', NULL);

--uc7
CREATE OR REPLACE PROCEDURE update_deaths(
    p_country_id INT,
    p_date DATE,
    p_deaths INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE covid_case_stats
    SET deaths = p_deaths
    WHERE country_id = p_country_id
      AND report_date = p_date;
END;
$$;
CALL update_deaths(1, '2020-01-30', 50);

--UC8
CREATE OR REPLACE VIEW v_country_cases_specific_date AS
SELECT 
    c.name AS country,
    SUM(cs.confirmed) AS confirmed,
    SUM(cs.deaths) AS deaths,
    SUM(cs.recovered) AS recovered
FROM country c
JOIN covid_case_stats cs
    ON c.country_id = cs.country_id
WHERE cs.report_date = '2020-01-30'
GROUP BY c.country_id, c.name;

SELECT * 
FROM v_country_cases_specific_date;

--UC9 — Latest data for each country
CREATE OR REPLACE VIEW v_latest_country_data AS
SELECT 
    c.name AS country,
    cs.report_date,
    SUM(cs.confirmed) AS confirmed,
    SUM(cs.deaths) AS deaths,
    SUM(cs.recovered) AS recovered
FROM country c
JOIN covid_case_stats cs
    ON c.country_id = cs.country_id
WHERE cs.report_date = (
    SELECT MAX(report_date)
    FROM covid_case_stats
)
GROUP BY c.country_id, c.name, cs.report_date;

--UC10
SELECT 
    c.name AS country,
    SUM(cs.confirmed + cs.deaths + cs.recovered) AS total_cases
FROM country c
JOIN covid_case_stats cs
    ON c.country_id = cs.country_id
GROUP BY c.country_id, c.name
ORDER BY total_cases DESC;


--UC11
SELECT 
    c.name AS country,
    SUM(cs.new_confirmed) AS total_new_cases
FROM country c
JOIN covid_case_stats cs
    ON c.country_id = cs.country_id
WHERE cs.report_date = '2020-01-30'
GROUP BY c.country_id, c.name
ORDER BY total_new_cases DESC
LIMIT 1;

--UC12:
WITH latest_dates AS (
    SELECT DISTINCT report_date
    FROM global_covid_stats
    ORDER BY report_date DESC
    LIMIT 2
),
country_data AS (
    SELECT
        country_id,
        MAX(CASE
            WHEN report_date = (SELECT MIN(report_date) FROM latest_dates)
            THEN confirmed
        END) AS previous_confirmed,
        MAX(CASE
            WHEN report_date = (SELECT MAX(report_date) FROM latest_dates)
            THEN confirmed
        END) AS latest_confirmed
    FROM global_covid_stats
    GROUP BY country_id
)
SELECT
    c.name AS country,
    previous_confirmed,
    latest_confirmed,
    ROUND(
        ((latest_confirmed - previous_confirmed) * 100.0)
        / NULLIF(previous_confirmed, 0),
        2
    ) AS percentage_increase
FROM country_data cd
JOIN country c
    ON cd.country_id = c.country_id
ORDER BY percentage_increase DESC;
--UC13
WITH latest_data AS (
    SELECT
        country_id,
        active_cases
    FROM global_covid_stats
    WHERE report_date = (
        SELECT MAX(report_date)
        FROM global_covid_stats
    )
)
SELECT
    c.name AS country,
    l.active_cases
FROM latest_data l
JOIN country c
    ON l.country_id = c.country_id
ORDER BY l.active_cases DESC
LIMIT 1;
--UC14
/*
Indexes are used to speed up data retrieval from database tables. In the COVID dataset, tables such as covid_case_stats may contain a large number of records, so searching the entire table for every query can be slow.
Indexes allow PostgreSQL to locate required rows more efficiently instead of performing a full table scan.
For example, queries frequently filtering by report_date can benefit from an index:
CREATE INDEX idx_covid_case_stats_report_date
ON covid_case_stats(report_date);
Similarly, indexes on columns used for JOINs, such as country_id and state_id, can improve join performance.
Indexes are particularly useful for:
- WHERE conditions, such as filtering by report_date
- JOIN conditions, such as country_id and state_id
- ORDER BY operations in suitable cases
- Searching large datasets efficiently
However, indexes also require additional storage and can make INSERT, UPDATE, and DELETE operations slightly more expensive because the indexes must also be maintained.
Therefore, indexes should be created on columns that are frequently searched, filtered, joined, or sorted, rather than on every column.
*/

--UC15
CREATE INDEX idx_country_name
ON country (name);