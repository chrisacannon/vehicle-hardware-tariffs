-- 14_duty_estimate.sql
-- Purpose: estimate what 2025's vehicle-hardware imports would owe under current
-- (October 2026) tariff rules, by assigning each origin a tariff tier.
-- Reads: clean.vehicle_hw   Writes: clean.vehicle_duty_est
-- Rules and sources: data/tariff_layers.csv   Findings: F2 (findings.md)
-- Safe to rerun: DROP TABLE IF EXISTS rebuilds the table each time.

-- 15.1 Build clean.vehicle_duty_est (2025 imports only)
-- Step 1 (tiered): assign each country a tier.
--   USMCA: Mexico, Canada. Qualifying parts are exempt from the Section 232
--          auto-parts tariff (Proclamation 10908, clause 4); all Mexico/Canada
--          imports are assumed to qualify.
--   Trade-deal partner: Japan, South Korea, Taiwan, the UK and the 27 EU members, listed by
--                       name as DataWeb spells them (e.g. 'Czechia (Czech Republic)').
--   All other origins: everyone else, including China.
-- Step 2: assign each row an estimated rate.
--   USMCA 0%; UK 10%; other deal partners 15% (all-in rates replacing base duty + 232;
--   secondary source, footnoted as an estimate); all others base duty + 25% Section 232.
--   The UK line comes before the deal-partner line on purpose: a CASE takes the first match.
--   China's rate excludes legacy Section 301 duties, so it is a floor.
DROP TABLE IF EXISTS 
	clean.vehicle_duty_est;
CREATE TABLE 
	clean.vehicle_duty_est AS
WITH tiered AS (
    SELECT 
		*,
        CASE
        	WHEN country IN ('Mexico', 'Canada') THEN 'USMCA'
        	WHEN country IN ('Japan', 'South Korea', 'Taiwan', 'United Kingdom',
                              'Austria', 'Belgium', 'Bulgaria', 'Croatia', 'Cyprus',
                              'Czechia (Czech Republic)', 'Denmark', 'Estonia', 'Finland',
                              'France', 'Germany', 'Greece', 'Hungary', 'Ireland', 'Italy',
                              'Latvia', 'Lithuania', 'Luxembourg', 'Malta', 'Netherlands',
                              'Poland', 'Portugal', 'Romania', 'Slovakia', 'Slovenia',
                              'Spain', 'Sweden')
            	THEN 'Trade-deal partner'
            ELSE 'All other origins'
        END AS tariff_tier
	FROM 
		clean.vehicle_hw
    WHERE 
		yr = 2025
)
SELECT 
	*,
    CASE
    	WHEN tariff_tier = 'USMCA'              THEN 0
    	WHEN country = 'United Kingdom'         THEN 0.10
    	WHEN tariff_tier = 'Trade-deal partner' THEN 0.15
        ELSE general_rate + 0.25
    END AS est_tariff_rate
FROM 
	tiered;

-- 15.2a Check: every row has a rate.
-- Expect: 221 rows, 0 NULL rates.
SELECT
	COUNT(*) AS row_count,
	SUM(CASE WHEN est_tariff_rate IS NULL THEN 1 ELSE 0 END) AS null_count
FROM
	clean.vehicle_duty_est;

-- 15.2b Summary by tier: import value, estimated tariff and effective rate ($M, %).
-- Effective rate = total tariff / total value (value-weighted, not an average of rates).
-- Expect:
--   USMCA               $1,863.9M   $0.0M     0.0%
--   Trade-deal partner  $1,110.1M   $165.7M  14.9%  (below 15% because the UK is at 10%)
--   All other origins     $752.9M   $206.8M  27.5%
-- The dashboard's Page 2 table is checked against this result (V6).
SELECT
	tariff_tier,
	ROUND(SUM(customs_value) / 1e6, 1) AS total_value,
	ROUND(SUM(customs_value * est_tariff_rate) / 1e6, 1) AS total_est_tariff,
	ROUND(100 * SUM(customs_value * est_tariff_rate) / SUM(customs_value), 1) AS effective_rate
FROM
	clean.vehicle_duty_est
GROUP BY
	1
ORDER BY	
	2 DESC;