-- 11_build_vehicle_hw.sql
-- Purpose: narrow the full trade table to the vehicle-hardware segment
-- (locks, hinges, and fittings and mountings for motor vehicles) and add the
-- product and origin groupings the dashboard uses.
-- Reads: clean.trade, clean.trade_rated   Writes: clean.vehicle_hw
-- Log entries: D4, D14
-- Safe to rerun: DROP TABLE IF EXISTS rebuilds the table each time.

-- 12.1 Which codes mention motor vehicles?
-- Expect: 6 codes, but one is a false match. 8302496055 is aircraft and vessel hardware;
-- its description says "(EXCEPT MOTOR VEH)", and a text search can't read "except".
-- A code the search misses also belongs: 8302303010 (gas struts) sits under heading
-- 8302.30, "suitable for motor vehicles". So the segment is defined by an explicit,
-- reviewed list of codes (12.2), not by this search (D14).
SELECT
	DISTINCT hts10, 
	description
FROM
	clean.trade
WHERE
	description ILIKE '%motor veh%';

-- 12.2 Build clean.vehicle_hw
--   WHERE hts10 IN (...): the 6 reviewed codes from 12.1 (D14)
--   product_group: Locks (8301.20), Hinges (8302.10.30), Fittings & mountings (8302.30)
--   origin_group: USMCA, China, Hong Kong / Macau, Rest of world. Hong Kong and Macau
--                 stay separate from China: under 0.1% of value, and their tariff
--                 treatment isn't assumed to match China's (D4).
DROP TABLE IF EXISTS 
	clean.vehicle_hw;
CREATE TABLE 
	clean.vehicle_hw AS
SELECT 
	tr.*,
    CASE
    	WHEN hts8 = '83012000' THEN 'Locks'
    	WHEN hts8 = '83021030' THEN 'Hinges'
    	ELSE 'Fittings & mountings'
    END AS product_group,
    CASE
    	WHEN country IN ('Mexico', 'Canada')    THEN 'USMCA (Mexico, Canada)'
    	WHEN country = 'China'                  THEN 'China'
    	WHEN country IN ('Hong Kong', 'Macau')  THEN 'Hong Kong / Macau'
    	ELSE 'Rest of world'
    END AS origin_group
FROM 
	clean.trade_rated tr
WHERE 
	hts10 IN ('8301200030', '8301200060', '8302103000',
              '8302303010', '8302303060', '8302306000');

-- 12.3 Check: rows, codes and 2025 value.
-- Expect: 1,688 rows, 6 codes, 2025 value of about $3.73B.
-- FILTER limits only the value column to 2025; a WHERE would have limited
-- all three columns (221 rows instead of 1,688).
SELECT
	COUNT(*) AS row_count,
	COUNT(DISTINCT hts10) AS code_count,
	SUM(customs_value) FILTER (WHERE yr = 2025) AS value_2025
FROM
	clean.vehicle_hw;