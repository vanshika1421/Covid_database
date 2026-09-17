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
