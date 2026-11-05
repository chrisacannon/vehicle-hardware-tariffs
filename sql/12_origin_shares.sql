-- 12_origin_shares.sql
-- Purpose: measure who supplies the vehicle-hardware market and how that has shifted.
-- Reads: clean.vehicle_hw   Writes: nothing (analysis queries)
-- Findings: F1 (findings.md)

-- 13.1 Value and share of each origin group, 2019 vs. 2025
-- SUM(SUM(customs_value)) OVER (PARTITION BY yr): a window function. The inner SUM is
-- each origin's value; the outer SUM ... OVER gives that year's grand total on every
-- row, without collapsing the rows. Origin value / year total = share.
-- Expect: USMCA 47.6% -> 50.0%; China 16.9% -> 12.2%.
-- The dashboard's Origin Share measure is checked against this result (V6).
SELECT 
	yr,
    origin_group,
    ROUND(SUM(customs_value) / 1e6, 1) AS value_m,
    ROUND(100 * SUM(customs_value)
    	/ SUM(SUM(customs_value)) OVER (PARTITION BY yr), 1) AS share_pct
FROM 
	clean.vehicle_hw
WHERE 
	yr IN (2019, 2025)
GROUP BY 
	yr, origin_group
ORDER BY 
	yr, value_m DESC;

-- 13.2 Top 10 supplier countries, 2025 ($M)
-- Used to see what makes up "Rest of world" once Mexico, Canada and China are set aside.
-- Expect: Japan and South Korea next after the top three (about $350–370M each),
-- together about half of Rest of world ($719M of $1.41B).
SELECT
	country,
	ROUND(SUM(customs_value) / 1e6, 1) AS value
FROM
	clean.vehicle_hw
WHERE
	yr = 2025
GROUP BY
	country
ORDER BY 
	value DESC
LIMIT
	10;