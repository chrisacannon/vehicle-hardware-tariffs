-- 03_profile_trade.sql
-- Purpose: profile the raw trade file before cleaning anything.
-- Reads: raw.dataweb_imports   Writes: nothing (read-only checks)
-- Log entries: D1, D2, D3, D4; V1, V2

-- 4.1 Which rows aren't trade data?
-- Expect: 3,141 'Customs Value' rows, plus 4 non-data rows (title, header,
-- 'Data Row Count', 'Total'), one row each. Those 4 are filtered out everywhere after this (D1).
SELECT 
	data_type, 
	COUNT(*) AS row_count
FROM 
	raw.dataweb_imports
GROUP BY 
	data_type
ORDER BY 
	row_count DESC;

-- 4.2 How many countries and HTS codes have real trade (non-zero in at least one year)?
-- Expect: 178 countries, 58 codes. Without the zero filter it's 179: Eritrea never shipped (D2).
-- OR, not AND: "non-zero in ANY year". AND would mean "non-zero in EVERY year" (V2).
SELECT 
	COUNT(DISTINCT country) AS countries,
    COUNT(DISTINCT hts_number) AS hts_codes
FROM 
	raw.dataweb_imports
WHERE 
	data_type = 'Customs Value'
  	AND (  y2019::numeric != 0
       OR y2020::numeric != 0
       OR y2021::numeric != 0
       OR y2022::numeric != 0
       OR y2023::numeric != 0
       OR y2024::numeric != 0
       OR y2025::numeric != 0
       OR y2026_jan_aug::numeric != 0
	  );

-- 4.3 Check: every HTS code is exactly 10 digits.
-- Expect: no rows (no code fails the format).
SELECT 
	hts_number, 
	LENGTH(hts_number)
FROM 
	raw.dataweb_imports
WHERE 
	data_type = 'Customs Value'
  	AND hts_number !~ '^[0-9]{10}$';

-- 4.4 Which country/code rows are zero in every year?
-- Expect: 8 rows (e.g., Eritrea 8302303060, Uruguay x4). Dropped in 08 (D2).
SELECT 
	country, 
	hts_number
FROM 
	raw.dataweb_imports
WHERE 
	data_type = 'Customs Value'
  	AND y2019::numeric = 0
  	AND y2020::numeric = 0
  	AND y2021::numeric = 0
  	AND y2022::numeric = 0
  	AND y2023::numeric = 0
  	AND y2024::numeric = 0
  	AND y2025::numeric = 0
  	AND y2026_jan_aug::numeric = 0;

-- 4.5 Is every value in the country column actually a country?
-- Expect: yes, no regions or aggregates (a manual scan of the sorted list).
-- Hong Kong and Macau are listed separately from China (D4).
SELECT 
	DISTINCT country
FROM 
	raw.dataweb_imports
WHERE 
	data_type = 'Customs Value'
ORDER BY 
	country;

-- 4.5b Check: country names with leading or trailing spaces.
-- A stray space is invisible in the result grid, so this checks for it directly.
-- Expect: 1 row, "Montserrat " (D3, trimmed in 08).
SELECT 
	DISTINCT country
FROM 
	raw.dataweb_imports
WHERE 
	data_type = 'Customs Value'
	AND country <> TRIM(country);