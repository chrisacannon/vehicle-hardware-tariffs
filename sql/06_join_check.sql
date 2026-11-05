-- 06_join_check.sql
-- Purpose: test whether every trade code can find its duty rate in the schedule,
-- before building the real join in 09.
-- Reads: raw.dataweb_imports, raw.hts_schedule   Writes: nothing (read-only checks)
-- Log entries: D7, D13

-- 7.1 Normalize schedule codes to the trade format (remove the dots).
-- Expect: 8301.10.60 becomes 83011060, and so on.
SELECT 
	hts_number,
    REPLACE(hts_number, '.', '') AS hts_clean
FROM 
	raw.hts_schedule
WHERE 
	hts_number <> ''
LIMIT 
	10;

-- 7.2 Which trade codes have no exact 10-digit match in the schedule?
-- LEFT JOIN keeps every trade row; s.hts_number IS NULL keeps only the ones that found no match.
-- Expect: 3 orphans, the retired codes from D12.
SELECT 
	DISTINCT t.hts_number
FROM 
	raw.dataweb_imports t
	LEFT JOIN raw.hts_schedule s
    	ON t.hts_number = REPLACE(s.hts_number, '.', '')
WHERE 
	t.data_type = 'Customs Value'
  		AND s.hts_number is null;          

-- 7.3 Match on the 10-digit code OR its 8-digit parent.
-- Neither works alone: exact 10-digit leaves 3 orphans, 8-digit alone leaves 17
-- (codes ending in 00, which have no separate 8-digit row).
-- Expect: 0 orphans.
-- Note: against the raw schedule, some codes match twice (their own blank row and
-- their parent). DISTINCT hides that here; 09 avoids it by joining to
-- rate-carrying lines only (D13).
SELECT 
	DISTINCT t.hts_number
FROM 
	raw.dataweb_imports t
	LEFT JOIN raw.hts_schedule s
    	ON t.hts_number = REPLACE(s.hts_number, '.', '')
		OR LEFT(t.hts_number, 8) = REPLACE(s.hts_number, '.', '')
WHERE 
	t.data_type = 'Customs Value'
  		AND s.hts_number is null;          