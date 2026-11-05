-- 10_reconcile.sql
-- Purpose: prove the clean table still adds up to the source file's own published total.
-- The DataWeb Total row is an independent control total; if cleaning, trimming,
-- reshaping and joining lost or double-counted anything, the years won't match.
-- Reads: clean.trade_rated, raw.dataweb_imports   Writes: nothing (read-only check)
-- Log entries: V5 (reconciliation)

-- 11.1 Reconcile clean totals to the DataWeb Total row, year by year
--   clean_totals: sum of the clean table by year, rounded to whole dollars like the source
--   source_totals: the Total row, unpivoted to one row per year (same LATERAL pattern as 08).
--                  Its values are comma-formatted text ("9,627,505,157"), so the commas
--                  are removed before casting. Note the label is 'Total: ' with a colon and space.
-- Expect: difference = 0 in all 8 years
--         (2019 = 9,627,505,157 ... 2026 Jan–Aug = 7,213,196,279).
WITH clean_totals AS (
    SELECT 
		yr, 
		ROUND(SUM(customs_value), 0) AS clean_total
    FROM 
		clean.trade_rated
    GROUP BY 
		yr
),
source_totals AS (
    SELECT 
		v.yr,
        REPLACE(v.total_text, ',', '')::numeric AS source_total
    FROM 
		raw.dataweb_imports t
    CROSS JOIN LATERAL (VALUES
        (2019, t.y2019), (2020, t.y2020), (2021,t.y2021), (2022,t.y2022), (2023,t.y2023), (2024,t.y2024), (2025,t.y2025), (2026,t.y2026_jan_aug)
    ) AS v(yr, total_text)
    WHERE 
		t.data_type = 'Total: '
)
SELECT 
	s.yr,
    s.source_total,
    c.clean_total,
    c.clean_total - s.source_total AS difference
FROM 
	source_totals s
JOIN clean_totals c 
	ON c.yr = s.yr
ORDER BY 
	s.yr;