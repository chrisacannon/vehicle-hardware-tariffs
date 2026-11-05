-- 13_base_rates.sql
-- Purpose: look up the base duty and trade-agreement rates for the segment's rate lines,
-- as the first layer of the tariff model.
-- The tariff rules themselves (USMCA exemption, Section 232 auto parts, deal-partner rates),
-- with sources and verification status, are documented in data/tariff_layers.csv.
-- 14_duty_estimate.sql applies them.
-- Reads: clean.hts_rates, raw.hts_schedule   Writes: nothing (lookup query)

-- 14 Layer 1: base duty and trade-agreement exceptions for the segment's 4 rate lines.
-- The 6 vehicle-hardware codes get their rates from these 4 lines:
--   83012000   -> 8301200030, 8301200060   (8-digit parent)
--   8302103000 -> its own line             (code ending in 00)
--   83023030   -> 8302303010, 8302303060   (8-digit parent)
--   8302306000 -> its own line             (code ending in 00)
-- general_rate is the base duty the "all other origins" tier adds 25% to;
-- "S" in special_rate is USMCA (D10).
-- Expect: 4 rows, all with "S" (USMCA) in the special rate list.
--   83012000    5.7%   (locks)
--   8302103000  2%     (hinges)
--   83023030    2%     (fittings: gas struts and other)
--   8302306000  3.5%   (fittings: other)
-- So the "all other origins" tier pays 27%–30.7% depending on the product mix (base + 25%).
SELECT 
	r.hts_code, 
	s.general_rate, 
	s.special_rate
FROM 
	clean.hts_rates r
JOIN raw.hts_schedule s 
	ON REPLACE(s.hts_number, '.', '') = r.hts_code
WHERE 
	r.hts_code IN ('83012000', '8302103000', '83023030', '8302306000');