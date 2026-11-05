-- 08_build_trade.sql
-- Purpose: reshape the trade file from one column per year into one row per
-- country, HTS code and year, the shape every later step and the dashboard use.
-- Reads: raw.dataweb_imports   Writes: clean.trade
-- Log entries: D1, D2, D3, D5, D8, D12
-- Safe to rerun: DROP TABLE IF EXISTS rebuilds the table from raw each time.

-- 9.1 Build clean.trade (unpivot years into rows)
--   CROSS JOIN LATERAL (VALUES ...): for each raw row, creates 8 rows, one per year,
--                       each holding the year, a partial-year flag and that year's value.
--   TRIM(country): removes the trailing space in "Montserrat " (D3)
--   hts8: 8-digit code family, for trends that run through code splits (D12)
--   description: the trade file's own description, used for display (D8)
--   is_partial: true for 2026, which covers January–August only (D5)
--   WHERE data_type: drops the 4 non-data rows (D1)
--   WHERE value != 0: a missing row already means "no trade that year", so zero rows
--                     are dropped. This also removes the 8 all-zero rows (D2).
DROP TABLE IF EXISTS 
	clean.trade;
CREATE TABLE 
	clean.trade AS
SELECT 
	TRIM(t.country) AS country,
    t.hts_number            AS hts10,
    LEFT(t.hts_number, 8)   AS hts8,
    t.description,
    v.yr,
    v.is_partial,
    v.customs_value
FROM 
	raw.dataweb_imports t
CROSS JOIN LATERAL (VALUES
    (2019, false, t.y2019::numeric),
    (2020, false, t.y2020::numeric),
    (2021, false, t.y2021::numeric),
    (2022, false, t.y2022::numeric),
    (2023, false, t.y2023::numeric),
    (2024, false, t.y2024::numeric),
    (2025, false, t.y2025::numeric),
    (2026, true,  t.y2026_jan_aug::numeric)
) AS v(yr, is_partial, customs_value)
WHERE 
	t.data_type = 'Customs Value'
  	AND v.customs_value != 0;

-- 9.2a Check: rows, countries and codes after the reshape.
-- Expect: 14,673 rows, 178 countries, 58 codes.
-- 3,141 raw rows x 8 years = 25,128 possible values, minus 10,455 zeros = 14,673.
-- Countries and codes match the 4.2 baseline, so nothing was lost or duplicated.
SELECT
	COUNT(*) as row_count,
	COUNT(DISTINCT country) as countries,
	COUNT(DISTINCT hts10) as hts_codes
FROM
	clean.trade;

-- 9.2b Check: trimming didn't create a duplicate Montserrat.
-- Expect: 1 row, "Montserrat" with no trailing space (it was the only spelling, D3).
SELECT 
	DISTINCT country
FROM 
	clean.trade
WHERE 
	country LIKE 'Montserrat%';