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

--UC16
CREATE OR REPLACE FUNCTION calculate_mortality_rate(p_country_name VARCHAR)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_deaths NUMERIC;
    v_confirmed NUMERIC;
BEGIN
    SELECT
        SUM(cs.deaths),
        SUM(cs.confirmed)
    INTO
        v_deaths,
        v_confirmed
    FROM covid_case_stats cs
    JOIN country c
        ON cs.country_id = c.country_id
    WHERE c.name = p_country_name;

    IF v_confirmed IS NULL OR v_confirmed = 0 THEN
        RETURN 0;
    END IF;

    RETURN (v_deaths / v_confirmed) * 100;
END;
$$;

SELECT calculate_mortality_rate('India');

--UC17
CREATE OR REPLACE FUNCTION calculate_recovery_rate(p_date DATE)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_recovered NUMERIC;
    v_confirmed NUMERIC;
BEGIN
    SELECT
        SUM(cs.recovered),
        SUM(cs.confirmed)
    INTO
        v_recovered,
        v_confirmed
    FROM covid_case_stats cs
    WHERE cs.report_date = p_date;

    IF v_confirmed IS NULL OR v_confirmed = 0 THEN
        RETURN 0;
    END IF;

    RETURN (v_recovered / v_confirmed) * 100;
END;
$$;
SELECT calculate_recovery_rate(DATE '2020-01-30');
--UC18
SELECT
    c.continent,
    SUM(cs.confirmed) AS total_confirmed_cases
FROM covid_case_stats cs
JOIN country c
    ON cs.country_id = c.country_id
GROUP BY
    c.continent
ORDER BY
    c.continent;

--UC19
SELECT
    report_date,
    SUM(deaths) AS total_deaths,
    SUM(recovered) AS total_recoveries
FROM covid_case_stats
GROUP BY
    report_date
ORDER BY
    report_date;

--UC20
WITH daily_cases AS (
    SELECT
        c.name AS country,
        cs.report_date,
        cs.confirmed,
        LAG(cs.confirmed) OVER (
            PARTITION BY cs.country_id
            ORDER BY cs.report_date
        ) AS previous_confirmed
    FROM covid_case_stats cs
    JOIN country c
        ON cs.country_id = c.country_id
)
SELECT
    country,
    AVG(confirmed - previous_confirmed) AS average_daily_new_cases
FROM daily_cases
WHERE previous_confirmed IS NOT NULL
GROUP BY
    country
ORDER BY
    country;


/*
============================================================
COVID-DATA-GLOBAL
============================================================
*/


/*
21. To find out the death percentage locally and globally.

Global
*/

SELECT
    ROUND(
        (
            SUM(deaths) * 100.0
            / NULLIF(SUM(confirmed), 0)
        )::NUMERIC,
        2
    ) AS global_death_percentage
FROM global_covid_stats;


/*
21. Country-wise
*/

SELECT
    c.name AS country,
    ROUND(
        (
            MAX(g.deaths) * 100.0
            / NULLIF(MAX(g.confirmed), 0)
        )::NUMERIC,
        2
    ) AS death_percentage
FROM global_covid_stats g
JOIN country c
    ON g.country_id = c.country_id
GROUP BY c.name
ORDER BY death_percentage DESC;


/*
22. To find out the infected population percentage locally
    and globally.

Global
*/

SELECT
    ROUND(
        (
            SUM(g.confirmed) * 100.0
            / NULLIF(SUM(c.population), 0)
        )::NUMERIC,
        2
    ) AS global_infected_population_percentage
FROM global_covid_stats g
JOIN country c
    ON g.country_id = c.country_id;


/*
22. Country-wise
*/

SELECT
    c.name AS country,
    ROUND(
        (
            MAX(g.confirmed) * 100.0
            / NULLIF(MAX(c.population), 0)
        )::NUMERIC,
        2
    ) AS death_percentage
FROM global_covid_stats g
JOIN country c
    ON g.country_id = c.country_id
GROUP BY c.name
ORDER BY death_percentage DESC;


/*
23. To find out the countries with the highest infection rates
*/

SELECT
    c.name AS country,
    c.population,
    MAX(g.confirmed) AS confirmed_cases,
    ROUND(
        (
            MAX(g.confirmed) * 100.0
            / NULLIF(c.population, 0)
        )::NUMERIC,
        2
    ) AS infected_population_percentage
FROM global_covid_stats g
JOIN country c
    ON g.country_id = c.country_id
GROUP BY
    c.name,
    c.population
ORDER BY infected_population_percentage DESC;


/*
24. To find out the countries and continents with the
    highest death counts.

The screenshot for this use case contains the same query
shown for Use Case 23. It is kept unchanged for consistency
with the submitted screenshots.
*/

SELECT
    c.name AS country,
    c.population,
    MAX(g.confirmed) AS confirmed_cases,
    ROUND(
        (
            MAX(g.confirmed) * 100.0
            / NULLIF(c.population, 0)
        )::NUMERIC,
        2
    ) AS infection_rate
FROM global_covid_stats g
JOIN country c
    ON g.country_id = c.country_id
GROUP BY
    c.name,
    c.population
ORDER BY infection_rate DESC;


/*
25. Average number of deaths by day
    (Continents and Countries)
    [Hint: order by, group by clause]

By Country
*/

SELECT
    c.name AS country,
    AVG(g.new_deaths) AS average_daily_deaths
FROM global_covid_stats g
JOIN country c
    ON g.country_id = c.country_id
GROUP BY c.name
ORDER BY average_daily_deaths DESC;


/*
25. By Continent
*/

SELECT
    c.continent,
    AVG(g.new_deaths) AS average_daily_deaths
FROM global_covid_stats g
JOIN country c
    ON g.country_id = c.country_id
GROUP BY c.continent
ORDER BY average_daily_deaths DESC;


/*
26. Average of cases divided by the number of population
    of each country (TOP 10)
    [Hint: Limit]
*/

SELECT
    c.name AS country,
    c.population,
    AVG(g.confirmed) AS average_cases,
    ROUND(
        (
            AVG(g.confirmed) * 100.0
            / NULLIF(c.population, 0)
        )::NUMERIC,
        2
    ) AS cases_population_percentage
FROM global_covid_stats g
JOIN country c
    ON g.country_id = c.country_id
GROUP BY
    c.name,
    c.population
ORDER BY cases_population_percentage DESC
LIMIT 10;


/*
27. Considering the highest value of total cases, which
    countries have the highest rate of infection in relation
    to population?
    [Hint: Where clause]
*/

SELECT
    c.name AS country,
    c.population,
    MAX(g.confirmed) AS total_cases,
    ROUND(
        (
            MAX(g.confirmed) * 100.0
            / NULLIF(c.population, 0)
        )::NUMERIC,
        2
    ) AS infection_rate
FROM global_covid_stats g
JOIN country c
    ON g.country_id = c.country_id
GROUP BY
    c.name,
    c.population
HAVING MAX(g.confirmed) > 0
ORDER BY infection_rate DESC;


/*
28. Countries with the highest number of deaths
*/

SELECT
    c.name AS country,
    MAX(g.deaths) AS total_deaths
FROM global_covid_stats g
JOIN country c
    ON g.country_id = c.country_id
GROUP BY c.name
ORDER BY total_deaths DESC;


/*
29. Continents with the highest number of deaths
*/

SELECT
    c.continent,
    SUM(g.deaths) AS total_deaths
FROM global_covid_stats g
JOIN country c
ON g.country_id = c.country_id
GROUP BY c.continent
ORDER BY total_deaths DESC;


/*
============================================================
QUERIES ON VACCINATION
============================================================
*/


/*
30. Total vaccinated with at least 1 dose over time
    (All countries)
*/

SELECT
    v.date,
    SUM(v.first_dose) AS total_people_vaccinated
FROM vaccination v
GROUP BY v.date
ORDER BY v.date;


/*
31. Percentage of the population vaccinated with at least
    the first dose until 30/9/2021 (Top 3)
*/

SELECT
    c.name AS country,
    c.population,
    SUM(v.first_dose) AS people_vaccinated_first_dose,
    ROUND(
        (
            SUM(v.first_dose) * 100.0
            / NULLIF(c.population, 0)
        )::NUMERIC,
        2
    ) AS vaccination_percentage
FROM vaccination v
JOIN state s
    ON v.state_id = s.state_id
JOIN country c
    ON s.country_id = c.country_id
WHERE v.date <= '2021-09-30'
GROUP BY
    c.name,
    c.population
ORDER BY vaccination_percentage DESC
LIMIT 3;

/*
============================================================
STATE-WISE COVID QUERIES
============================================================
*/


/*
35. Total State-wise Confirmed Cases
*/

SELECT
    s.name AS state,
    SUM(cs.confirmed) AS total_confirmed_cases
FROM covid_case_stats cs
JOIN state s
    ON cs.state_id = s.state_id
GROUP BY s.name
ORDER BY total_confirmed_cases DESC;


/*
36. Maximum Active cases State-wise till date
*/

SELECT
    s.name AS state,
    MAX(cs.active_cases) AS maximum_active_cases
FROM covid_case_stats cs
JOIN state s
    ON cs.state_id = s.state_id
GROUP BY s.name
ORDER BY maximum_active_cases DESC;


/*
37. Max Per Day Confirmed cases in States
*/

SELECT
    s.name AS state,
    MAX(cs.new_confirmed) AS maximum_daily_confirmed_cases
FROM covid_case_stats cs
JOIN state s
    ON cs.state_id = s.state_id
GROUP BY s.name
ORDER BY maximum_daily_confirmed_cases DESC;


/*
38. Max Per Day Death cases in States
*/

SELECT
    s.name AS state,
    MAX(cs.new_deaths) AS maximum_daily_deaths
FROM covid_case_stats cs
JOIN state s
    ON cs.state_id = s.state_id
GROUP BY s.name
ORDER BY maximum_daily_deaths DESC;


/*
39. State-wise Mortality Rate
*/

SELECT
    s.name AS state,
    SUM(cs.confirmed) AS confirmed_cases,
    SUM(cs.deaths) AS deaths,
    ROUND(
        (
            SUM(cs.deaths) * 100.0
            / NULLIF(SUM(cs.confirmed), 0)
        )::NUMERIC,
        2
    ) AS mortality_rate
FROM covid_case_stats cs
JOIN state s
    ON cs.state_id = s.state_id
GROUP BY s.name
ORDER BY mortality_rate DESC;

