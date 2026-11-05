-- 07_build_hts_rates.sql
-- Purpose: build a clean lookup of duty rates, one row per tariff line that carries a rate.
-- Reads: raw.hts_schedule   Writes: clean.hts_rates
-- Log entries: D6, D7, D10, D11
-- Safe to rerun: DROP TABLE IF EXISTS rebuilds the table from raw each time.

-- 8.1 Build clean.hts_rates
-- hts_code: dots removed, to match the trade file's format (7.1)
-- general_rate: "Free" -> 0; "6.1%" -> 0.061; anything else (compound rates) -> NULL (D11)
-- usmca_free: true if "S" (USMCA) appears as its own code in the Special Rate list.
--             The regex requires a separator on both sides, so "SG" (Singapore) doesn't match (D10).
-- WHERE NULLIF(...): turns blanks ('') into NULL and drops them, keeping only lines that
--                    carry a rate. 10-digit children with blank rates get their parent's
--                    rate in the 09 join (D6, D7).
DROP TABLE IF EXISTS 
	clean.hts_rates;
CREATE TABLE 
	clean.hts_rates AS
SELECT 
	REPLACE(hts_number, '.', '')          AS hts_code,
    LENGTH(REPLACE(hts_number, '.', ''))  AS digits,
    general_rate                          AS general_rate_text,
    CASE
    	WHEN general_rate = 'Free'        THEN 0
        WHEN general_rate ~ '^[0-9.]+%$'  THEN REPLACE(general_rate, '%', '')::numeric / 100
        	ELSE NULL
        END                                   AS general_rate,
    special_rate ~ '[(, ]S[,)]'           AS usmca_free
FROM 
	raw.hts_schedule
WHERE 
	NULLIF(general_rate, '') IS NOT NULL;

-- 8.2a Check: rows by code length.
-- Expect: 41 ten-digit rows and 18 eight-digit rows (59 total).
SELECT
	digits,
	COUNT(*) AS row_count
FROM
	clean.hts_rates
GROUP BY
	1;

-- 8.2b Check: rows with no usable rate.
-- Expect: 1 row, 8308100000 (compound rate "1.1¢/kg + 2.9%"). It's outside the
-- 8301/8302 scope, so NULL is the right result.
SELECT
	*
FROM
	clean.hts_rates
WHERE 
	general_rate is null;

-- 8.3 Check: where is the USMCA flag false?
-- Expect: 15 rows, all with general rate "Free", so there's no special USMCA rate to list.
-- The effective USMCA duty is 0 either way.
SELECT
	*
FROM
	clean.hts_rates
WHERE
	usmca_free = false;