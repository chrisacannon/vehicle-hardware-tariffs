-- 04_profile_schedule.sql
-- Purpose: profile the raw tariff schedule before cleaning anything.
-- Reads: raw.hts_schedule   Writes: nothing (read-only checks)
-- Log entries: D6, D7, D8, D9, D11

-- 5.1 How many rows have a blank HTS number, and what are they?
-- Expect: 14 rows, all label rows (a description with no code) that group the lines below them.
-- Blanks loaded as '' rather than NULL, so IS NULL alone finds none of them (D6).
SELECT
	HTS_Number,
	indent,
	description
FROM
	raw.hts_schedule
WHERE
	HTS_Number is null
	OR hts_number = '';

-- 5.2 Which lines carry a General Rate, by number of digits (dots removed)?
-- Expect: 10-digit codes ending in 00 carry a rate (41); all other 10-digit codes
-- are blank (48), because they inherit their 8-digit parent's rate (D7).
SELECT 
	LENGTH(REPLACE(hts_number, '.', '')) AS digits,
    general_rate = '' AS rate_is_blank,
    COUNT(*) AS row_count
FROM 
	raw.hts_schedule
GROUP BY 
	1, 2
ORDER BY 
	1, 2;

-- 5.3 What is the general duty rate for 8301.10.60.20?
-- Expect: its own row is blank; the rate is 6.1%, on its 8-digit parent 8301.10.60 (D7).
SELECT 
	hts_number, 
	indent, 
	description, 
	general_rate
FROM 
	raw.hts_schedule
WHERE 
	hts_number LIKE '8301.10%';

-- 5.4 (no query) The USMCA code in the Special Rate column is "S".
-- Source: CBP USMCA FAQs; definitive source is HTS General Note 11 (D10).

-- 5.5 What formats appear in the General Rate column, within 8301 and 8302?
-- Expect: percentages ("6.1%"), "Free", and blanks (''). None of these casts
-- straight to a number: the % sign, the word Free and '' all break ::numeric (D11).
-- The one compound rate ("1.1¢/kg + 2.9%") is on 8308.10.00, outside this filter.
SELECT
	general_rate,
	COUNT(*) AS row_count
FROM
	raw.hts_schedule
WHERE 
	hts_number LIKE '8301%' 
		OR hts_number LIKE '8302%'
GROUP BY
	general_rate
ORDER BY
	row_count DESC;