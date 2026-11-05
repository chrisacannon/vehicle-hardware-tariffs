-- 05_code_changes.sql
-- Purpose: find HTS codes that start or stop during 2019–2026, and check whether
-- trade really changed or the codes were just renumbered.
-- Reads: raw.dataweb_imports   Writes: nothing (read-only checks)
-- Log entries: D12

-- 6.1 Which codes have trade in some years and exactly zero in others?
-- LEAST = 0 means "some year is zero"; GREATEST > 0 means "some year has trade".
-- Expect: 7 codes, all in three families (8301.10.60, 8301.60, 8301.70).
SELECT 
	hts_number,
    description,
    SUM(y2019::numeric) AS y2019,
    SUM(y2020::numeric) AS y2020,
    SUM(y2021::numeric) AS y2021,
	SUM(y2022::numeric) AS y2022,
	SUM(y2023::numeric) AS y2023,
	SUM(y2024::numeric) AS y2024,
	SUM(y2025::numeric) AS y2025,
	SUM(y2026_jan_aug::numeric) AS y2026_jan_aug
FROM 
	raw.dataweb_imports
WHERE 
	data_type = 'Customs Value'
GROUP BY 
	hts_number, description
HAVING 
	LEAST(SUM(y2019::numeric), SUM(y2020::numeric), SUM(y2021::numeric), SUM(y2022::numeric), SUM(y2023::numeric), SUM(y2024::numeric), SUM(y2025::numeric), SUM(y2026_jan_aug::numeric)) = 0
		AND GREATEST(SUM(y2019::numeric), SUM(y2020::numeric), SUM(y2021::numeric), SUM(y2022::numeric), SUM(y2023::numeric), SUM(y2024::numeric), SUM(y2025::numeric), SUM(y2026_jan_aug::numeric)) > 0
ORDER BY 
	hts_number;

-- 6.2a Year-by-year values for each code in the three split families
-- (only the years around the splits).
-- Expect: 8301106000 stops in 2020, replaced by 8301106020 and 8301106080.
-- 8301600000 and 8301700000 each split into two new codes in 2026;
-- 8301600000 drops from $391M to $34M because it was retired, not because trade fell.
SELECT 
	hts_number,
    SUM(y2019::numeric)          AS y2019,
    SUM(y2020::numeric)          AS y2020,
    SUM(y2024::numeric)          AS y2024,
    SUM(y2025::numeric)          AS y2025,
    SUM(y2026_jan_aug::numeric)  AS y2026_jan_aug
FROM 
	raw.dataweb_imports
WHERE 
	data_type = 'Customs Value'
  	AND (hts_number LIKE '83011060%'
    	OR hts_number LIKE '83016000%'
    	OR hts_number LIKE '83017000%')
GROUP BY 
	hts_number
ORDER BY 
	hts_number;

-- 6.2b Family totals: old and new codes combined.
-- Expect: each family's trade continues through the split, with no collapse.
-- The 2026 dip is the partial year (8 months against 12, D5), not the split.
-- This is why clean.trade carries an hts8 column for trend charts (D12).
SELECT 
	LEFT(hts_number, 8)          AS code_family,
    SUM(y2019::numeric)          AS y2019,
    SUM(y2020::numeric)          AS y2020,
    SUM(y2024::numeric)          AS y2024,
    SUM(y2025::numeric)          AS y2025,
    SUM(y2026_jan_aug::numeric)  AS y2026_jan_aug
FROM 
	raw.dataweb_imports
WHERE 
	data_type = 'Customs Value'
  	AND (hts_number LIKE '83011060%'
    	OR hts_number LIKE '83016000%'
    	OR hts_number LIKE '83017000%')
GROUP BY 
	LEFT(hts_number, 8)
ORDER BY 
	code_family;