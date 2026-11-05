# Cleaning Log — Tariff Exposure Project

## How this log works

- **One entry per problem**, not per task. Task numbers go in the **Where** line so a reviewer can trace them.
- **Data issues** are problems in the source data. **Validation notes** are checks on my own work: mistakes I caught and results that tied out.
- Every data issue has the same six fields:

| Field | What it says |
|---|---|
| **Where** | table, column, and the task/query that found it |
| **Found** | what's wrong, with the evidence |
| **Why it matters** | what would break or mislead if ignored |
| **Decision** | the plan (written when the problem is found) |
| **Done** | what was built, and in which file (written when fixed) |
| **Status** | Open / Done |

---

## Status summary

| ID | Issue | Status |
|---|---|---|
| D1 | Non-data rows in trade file | Done (9.1) |
| D2 | All-zero rows | Done (9.1) |
| D3 | Trailing space in country name | Done (9.1) |
| D4 | Hong Kong / Macau reported separately | Closed: immaterial (13.3) |
| D5 | 2026 is a partial year | Done (9.1) |
| D6 | Blanks loaded as '' not NULL | Done (8.1) |
| D7 | Duty rates live on the 8-digit line | Done (8.1, 10.1) |
| D8 | Schedule descriptions only make sense in context | Done (9.1) |
| D9 | Schedule row order carries meaning | Closed: no longer needed |
| D10 | USMCA indicator in Special Rate column | Done (8.1, verified 8.3) |
| D11 | General Rate has mixed formats | Done (8.1) |
| D12 | HTS code splits break single-code trends | Done (9.1) |
| D13 | Neither join works alone | Done (10.1, verified 10.2) |
| D14 | Text search mis-scopes the vehicle segment | Done (12.2) |

---

## Data issues

### D1. Non-data rows in the trade file
- **Where:** raw.dataweb_imports, data_type · 03_profile_trade.sql (4.1)
- **Found:** 4 rows that aren't trade data: a title row, a "Data Row Count" row, the column header row, and a "Total" row. The remaining 3,141 rows match the file's stated Data Row Count.
- **Why it matters:** the Total row would double-count any SUM, and its comma-formatted values break numeric casts.
- **Decision:** filter on `data_type = 'Customs Value'` everywhere.
- **Done:** filter in clean.trade (08_build_trade.sql).
- **Status:** Done

### D2. All-zero rows
- **Where:** raw.dataweb_imports, year columns · 03_profile_trade.sql (4.4)
- **Found:** 8 country/code rows are $0 in every year (e.g., Eritrea 8302303060, Uruguay ×4).
- **Why it matters:** no effect on totals, but they inflate counts: Eritrea is counted as a source country without ever shipping. Excluding them takes countries from 179 to 178.
- **Decision:** drop them.
- **Done:** clean.trade keeps only rows where customs_value ≠ 0. In the long format this removes every zero year-row, which includes all 8 all-zero rows (08_build_trade.sql).
- **Status:** Done

### D3. Trailing space in a country name
- **Where:** raw.dataweb_imports, country · 03_profile_trade.sql (4.5b)
- **Found:** "Montserrat " has a trailing space. It's the only spelling of that country in the file.
- **Why it matters:** an invisible space makes joins and filters silently fail to match.
- **Decision:** TRIM country names.
- **Done:** `TRIM(t.country)` in clean.trade (08_build_trade.sql).
- **Status:** Done

### D4. Hong Kong / Macau reported separately from China
- **Where:** raw.dataweb_imports, country · 03_profile_trade.sql (4.5)
- **Found:** both appear as their own countries. There are no aggregate or region rows in the country list.
- **Why it matters:** their tariff treatment may differ from China's. Grouping them wrong would misstate China exposure.
- **Decision:** verify current tariff treatment before building the tariff layer.
- **Done:** not needed for this analysis. In the vehicle-hardware segment, Hong Kong and Macau together are under 0.1% of value ($0.3M of $3.73B in 2025), so how they're treated can't move any result. They're kept as their own origin group ("Hong Kong / Macau") rather than merged into China, and their tariff treatment isn't researched (13.1, 13.3).
- **Status:** Closed (immaterial)

### D5. 2026 is a partial year
- **Where:** raw.dataweb_imports, y2026_jan_aug · Task 4.6
- **Found:** the last column covers Jan–Aug only, 8 months rather than 12.
- **Why it matters:** comparing it to full-year 2025 would show a fake drop of about 33%.
- **Decision:** flag 2026 as partial and exclude it from year-over-year growth. Optional later: re-pull DataWeb at monthly level to compare Jan–Aug 2026 against Jan–Aug 2025.
- **Done:** `is_partial` column in clean.trade (true for 2026) (08_build_trade.sql).
- **Status:** Done

### D6. Blanks loaded as empty strings, not NULL
- **Where:** raw.hts_schedule (blank HTS numbers, blank rates) · 04_profile_schedule.sql (5.1)
- **Found:** blank cells are `''`, not NULL, so `IS NULL` missed all 14 blank HTS numbers.
- **Why it matters:** any null check or COALESCE silently misses them.
- **Decision:** convert `''` to NULL with NULLIF.
- **Done:** `NULLIF(general_rate, '')` in clean.hts_rates (07_build_hts_rates.sql).
- **Status:** Done

### D7. Duty rates live on the 8-digit line, not the 10-digit
- **Where:** raw.hts_schedule, general_rate · 04_profile_schedule.sql (5.2, 5.3)
- **Found:** 10-digit codes ending in 00 carry a rate (41). All other 10-digit codes are blank (48). They're statistical breakouts that inherit their 8-digit parent's rate (e.g., 8301.10.60.20 gets 6.1% from 8301.10.60).
- **Why it matters:** trade data is at 10 digits. A direct join would show $0 duty on 48 codes.
- **Decision:** keep only rate-carrying lines; join trade codes to their own line or their 8-digit parent (see D13).
- **Done:** clean.hts_rates keeps only lines with a rate: 41 ten-digit and 18 eight-digit (07_build_hts_rates.sql). clean.trade_rated joins each trade row on `t.hts8 = r.hts_code OR t.hts10 = r.hts_code`. Verified: 0 rows without a rate (09_build_trade_rated.sql).
- **Status:** Done

### D8. Schedule descriptions only make sense in context
- **Where:** raw.hts_schedule, description · 04_profile_schedule.sql (5.2)
- **Found:** many child descriptions are just "Other" or a fragment. The blank-HTS label rows carry part of the meaning.
- **Why it matters:** a dashboard would show meaningless labels like "Other: $20M."
- **Decision:** take display names from the trade file's descriptions, which are complete on their own; use the schedule only for rates.
- **Done:** clean.trade carries the trade-file description (08_build_trade.sql).
- **Status:** Done

### D9. Schedule row order carries meaning
- **Where:** raw.hts_schedule · 04_profile_schedule.sql (5.2)
- **Found:** a child row's parent is the row above it. Postgres doesn't guarantee row order without ORDER BY, and the table has no row-number column.
- **Why it matters:** logic that depends on "the row above" could silently break.
- **Decision:** originally planned to add a row number on reload.
- **Done:** no longer needed. Rates are looked up by code (D7, D13), not by position, and display names come from the trade file (D8).
- **Status:** Closed

### D10. USMCA indicator in the Special Rate column
- **Where:** raw.hts_schedule, special_rate · Task 5.4
- **Found:** "S" = USMCA, e.g. `Free (A+,AU,...,S,SG)`. "S+" doesn't appear in Ch. 83. Source: CBP USMCA FAQs; the definitive source is HTS General Note 11.
- **Why it matters:** (1) `LIKE '%S%'` also matches SG (Singapore), so the check needs an exact match. (2) "Free" only applies if the good *qualifies* under USMCA rules of origin, not just because it shipped from Mexico or Canada.
- **Decision:** exact-match parse of the Special list; model "qualifying share" as a scenario assumption in Batch 3.
- **Done:** regex `'[(, ]S[,)]'` → `usmca_free` in clean.hts_rates (07_build_hts_rates.sql). Verified (8.3): false on 15 rows, all with general rate = Free, so the effective USMCA duty is 0 either way.
- **Status:** Done

### D11. General Rate has mixed formats
- **Where:** raw.hts_schedule, general_rate · 04_profile_schedule.sql (5.5)
- **Found:** percentages ("6.1%"), text ("Free"), blanks (''), and one compound rate ("1.1¢/kg + 2.9%" on 8308100000, outside 8301/8302 scope).
- **Why it matters:** only clean percentages can be cast, and only after removing the "%". Blanks are not zero (see D7).
- **Decision:** "Free" → 0; plain % → decimal (6.1% = 0.061), so duty = value × rate; anything else → NULL.
- **Done:** CASE in clean.hts_rates (07_build_hts_rates.sql). The only NULL is the out-of-scope compound rate.
- **Status:** Done

### D12. HTS code splits break single-code trends
- **Where:** raw.dataweb_imports · 05_code_changes.sql (6.1, 6.2a, 6.2b)
- **Found:** 7 codes start or stop within 2019–2026, all in three families. 8301106000 split into 8301106020/80 in 2020. 8301600000 and 8301700000 each split into two new codes in 2026. The old 8301.60 code carried about 1 month of trade in 2026, so the split likely took effect around Feb 2026. Codes aren't necessarily retired at the turn of the calendar year.
- **Why it matters:** charting a single code shows a fake collapse when it's retired (8301600000: $391M → $34M) and a fake "new product" when one is created. This stacks with D5: even the combined 8301.60 family looks down 36% in 2026, only because it's 8 months against 12.
- **Decision:** roll codes up to the 8-digit family for trend charts; keep 10-digit detail for drill-down. This works because all changes in 2019–2026 were within 8-digit families (6.2b); a change at the 8-digit level (e.g. a future HS revision) would need a concordance table to link old and new codes.
- **Done:** `hts8` column (`LEFT(hts_number, 8)`) in clean.trade (08_build_trade.sql).
- **Status:** Done

### D13. Trade codes vs. schedule: neither join works alone
- **Where:** raw.dataweb_imports + raw.hts_schedule · 06_join_check.sql (7.2, 7.3)
- **Found:** an exact 10-digit join leaves 3 orphans (the retired codes from D12). An 8-digit join leaves 17 orphans (codes ending in 00, which have no separate 8-digit row). Matching on either one leaves 0 orphans.
- **Why it matters:** either join alone would silently drop trade value from the tariff calculation.
- **Decision:** join on 10-digit OR 8-digit match, against rate-carrying lines only, so each code matches exactly once.
- **Done:** `ON t.hts8 = r.hts_code OR t.hts10 = r.hts_code` against rate-carrying lines only (09_build_trade_rated.sql). Verified (10.2): row count unchanged at 14,673, so no code matched twice; 0 rows without a rate line; 0 rows with a NULL rate.
- **Status:** Done

### D14. Text search mis-scopes the vehicle-hardware segment
- **Where:** clean.trade, description · 11_build_vehicle_hw.sql (12.1)
- **Found:** `ILIKE '%motor veh%'` returns 6 codes, but one is a false match: 8302496055 is hardware for aircraft and vessels, and its description reads "(EXCEPT MOTOR VEH)", the inverse of what the search was looking for. A second code needed a judgment call: 8302303010 (pneumatic cylinders, i.e. gas struts) doesn't say "hinge," "lock" or "fitting," but it sits under heading 8302.30, "mountings, fittings … suitable for motor vehicles," so it belongs.
- **Why it matters:** a text filter can't read "except." Scoping by keyword alone would pull aircraft and boat parts into a motor-vehicle analysis.
- **Decision:** define the segment with an explicit list of codes, reviewed one by one, instead of a text filter.
- **Done:** 6 codes listed explicitly in clean.vehicle_hw: 8301200030, 8301200060, 8302103000, 8302303010, 8302303060, 8302306000 (11_build_vehicle_hw.sql).
- **Status:** Done

---

## Validation notes

### V1. Row count reconciles to the file header
- 3,141 data rows loaded, matching the file's "Data Row Count." 179 countries, 58 HTS codes. (4.1, 4.2)
- All HTS codes are exactly 10 digits. Verified clean. (4.3)

### V2. AND vs. OR when excluding all-zero rows
- **Mistake:** used AND across years (non-zero in EVERY year) instead of OR (non-zero in ANY year).
- **Caught it by:** comparing to the 4.2 baseline. The wrong version returned 63 countries and 51 codes, far too big a drop for removing 8 rows.
- **Correct:** 178 countries and 58 codes. Only Eritrea drops out.
- **Lesson:** compare counts before and after every filter.

### V3. REPLACE vs. TRIM for country names
- **Mistake (caught before running):** the first draft used `REPLACE(country, ' ', '')`, which removes *every* space ("South Korea" → "SouthKorea").
- **Fix:** `TRIM()` only strips leading and trailing spaces.

### V4. Batch 2 build checks
- **clean.hts_rates:** 59 rows (41 ten-digit, 18 eight-digit). 1 NULL rate (8308100000, compound, out of scope). usmca_free false on 15 rows, all general rate = Free. ✔ (8.2, 8.3)
- **clean.trade:** 14,673 rows, 178 countries, 58 codes. ✔ (9.2) Each row is one year with non-zero trade for one country and code: 3,141 raw rows × 8 years = 25,128 possible values, minus 10,455 zero values. Country and code counts match Batch 1, so nothing was lost or duplicated in the reshape. "Montserrat" is now trimmed and still a single country.
- **clean.trade_rated:** 14,673 rows, equal to clean.trade, so no trade code matched twice. 0 rows without a rate line, so every row found a rate. 0 NULL rates, so every matched rate is usable ("Free" counts as 0). ✔ (10.2)

### V5. Join draft that looked fine but wasn't
- **Mistake:** the first draft of the 10.1 join compared the 8-digit code twice (`t.hts8 = …` OR `LEFT(t.hts10, 8) = …`) and had no 10-digit match.
- **Why it was dangerous:** a LEFT JOIN keeps every row, so the row count still looked right (14,673). But 3,917 rows (codes whose rate sits on a 10-digit "00" line) would have had no rate.
- **Caught by:** the orphan check (`rate_line IS NULL`). This is why the checks run after every build.
- **Lesson:** each side of an `=` must be able to be the same length: 8 against 8, 10 against 10.
- **Reconciliation to the DataWeb Total row:** clean.trade_rated sums to the source file's Total row with a **difference of $0 in all 8 years** (2019 = $9,627,505,157 ... 2026 Jan–Aug = $7,213,196,279). ✔ (11.1, 10_reconcile.sql) No value was lost or double-counted anywhere between the source file and the clean table, through the filtering, trimming, casting, reshaping and joining.

### V6. Dashboard reconciles to SQL
- **Page 1:** the 2019 and 2025 origin shares in Power BI match 13.1 (USMCA 47.6% → 50.0%, China 16.9% → 12.2%). ✔ (16.6)
- **Page 2:** the tier table matches 15.2 (USMCA $1,863.9M at 0.0%; trade-deal partners $1,110.1M at 14.9%; all other origins $752.9M at 27.5%). ✔ (16.6)
- **Why it matters:** Power BI recalculates every number with its own DAX measures, which can be wrong even when the SQL is right. An early version of `Origin Share` showed 100% on every card until its filter removal was fixed. A match proves the measures are right, not just the data.
