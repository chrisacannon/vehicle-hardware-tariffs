-- 09_build_trade_rated.sql
-- Purpose: attach a duty rate to every trade row.
-- Reads: clean.trade, clean.hts_rates   Writes: clean.trade_rated
-- Log entries: D7, D13; V5
-- Safe to rerun: DROP TABLE IF EXISTS rebuilds the table each time.

-- 10.1 Build clean.trade_rated
-- Each trade code finds its rate on either its own 10-digit line (codes ending in 00)
-- or its 8-digit parent (statistical breakouts that inherit the parent's rate).
-- Neither match works alone (7.2, 7.3). This join is safe from double matches because
-- clean.hts_rates holds only lines that carry a rate, so each code matches exactly once.
-- Each side of the = compares the same length: 8 against 8, 10 against 10 (V5).
DROP TABLE IF EXISTS 
	clean.trade_rated;
CREATE TABLE 
	clean.trade_rated AS
SELECT 
	t.*,
    r.hts_code     AS rate_line,
    r.general_rate,
    r.usmca_free
FROM 
	clean.trade t
LEFT JOIN clean.hts_rates r
    ON t.hts8 = r.hts_code
		OR t.hts10 = r.hts_code;

-- 10.2a Check: same number of rows as clean.trade?
-- Expect: 14,673 = 14,673. More would mean some codes matched twice.
SELECT 
	(SELECT COUNT(*) FROM clean.trade_rated) AS rated_rows,
    (SELECT COUNT(*) FROM clean.trade)       AS trade_rows;
	
-- 10.2b Check: rows that found no rate line (the anti-join from 7.2).
-- Expect: 0. This check caught the first join draft, which had the right row
-- count but left 3,917 rows without a rate (V5).
SELECT 
	COUNT(*) 
FROM 
	clean.trade_rated 
WHERE 
	rate_line IS NULL;

-- 10.2c Check: rows whose matched rate is NULL (unusable).
-- Expect: 0. "Free" counts as 0, not NULL.
SELECT 
	COUNT(*) 
FROM 
	clean.trade_rated 
WHERE 
	general_rate IS NULL;