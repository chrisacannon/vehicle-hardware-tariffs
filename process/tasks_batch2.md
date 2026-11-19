# Batch 2: Build the Clean Tables

**Goal:** turn the decisions in your cleaning log into three clean tables, then prove the numbers still tie out to the source file. Batch 1 found the problems. Batch 2 fixes them, and every fix comes from a log entry you already wrote.

**What you'll have at the end:**

| Table | One row per | Used for |
|---|---|---|
| `clean.hts_rates` | tariff line that carries a rate | looking up duty rates |
| `clean.trade` | country × HTS code × year | all trade analysis |
| `clean.trade_rated` | same as `clean.trade`, plus its duty rate | the dashboard (Batch 3) |

**How this batch is marked:**
- **[PASTE]** means run it as given. It contains a new concept, explained right below it.
- **[YOUR TURN]** means you write it. It only uses patterns from your cheat sheet.
- **Expect:** is the result you should get. If yours differs, send me your query.

**Files for this batch:**

| File | What goes in it |
|---|---|
| `07_build_hts_rates.sql` | Task 8 |
| `08_build_trade.sql` | Task 9 |
| `09_build_trade_rated.sql` | Task 10 |
| `10_reconcile.sql` | Task 11 |

---

## New concept for the whole batch: CREATE TABLE AS

Until now, every query only *displayed* results. This batch *saves* them as new tables:

```sql
DROP TABLE IF EXISTS clean.some_table;   -- delete the old version, if any
CREATE TABLE clean.some_table AS         -- save whatever the SELECT returns
SELECT ...;
```

The `DROP TABLE IF EXISTS` line means you can rerun the file as many times as you like. Each run rebuilds the table from scratch, from the raw data. The raw tables are never changed, which is the whole point of loading them untouched in Batch 1.

---

## Task 8: Build `clean.hts_rates`

*Log entries this uses: "Duty rates live on the 8-digit line," "Casting general rate," "USMCA indicator."*

### 8.1 [PASTE] Build the table

```sql
DROP TABLE IF EXISTS clean.hts_rates;
CREATE TABLE clean.hts_rates AS
SELECT REPLACE(hts_number, '.', '')          AS hts_code,
       LENGTH(REPLACE(hts_number, '.', ''))  AS digits,
       general_rate                          AS general_rate_text,
       CASE
         WHEN general_rate = 'Free'        THEN 0
         WHEN general_rate ~ '^[0-9.]+%$'  THEN REPLACE(general_rate, '%', '')::numeric / 100
         ELSE NULL
       END                                   AS general_rate,
       special_rate ~ '[(, ]S[,)]'           AS usmca_free
FROM raw.hts_schedule
WHERE NULLIF(general_rate, '') IS NOT NULL;
```

**What's new:**
- **`CASE WHEN ... THEN ... ELSE ... END`** is SQL's IF/ELSE, evaluated top to bottom. "Free" becomes 0. A plain percentage like `6.1%` becomes `0.061`. Anything else, such as the compound rate, becomes NULL, so a bad value can't sneak in.
- **`~ '^[0-9.]+%$'`** means "only digits and dots, then a % sign." It's the same regex idea as 4.3.
- **`~ '[(, ]S[,)]'`** finds the code `S` only when it stands alone in the list: preceded by `(`, a comma or a space, and followed by a comma or `)`. That fixes the `LIKE '%S%'` trap from 5.4, where `SG` would also match.
- **`WHERE NULLIF(general_rate, '') IS NOT NULL`** keeps only rows that carry a rate. It turns blanks into NULL and then drops them. That leaves out headings, label rows and the 10-digit children with blank rates. Those children get their rate from the parent row in Task 10.

### 8.2 [YOUR TURN] Check what you built

Write one query that counts the rows in `clean.hts_rates` grouped by `digits`.
**Expect:** 41 rows with 10 digits and 18 rows with 8 digits.

Then find the rows where `general_rate` is NULL.
**Expect:** exactly 1, the compound rate `8308.10.00.00` (hooks and eyelets). It's outside your 8301/8302 scope, so NULL is the right result.

### 8.3 [YOUR TURN] Sanity-check the USMCA flag

Find the rows where `usmca_free` is false and look at their `general_rate_text`.
**Expect:** 15 rows, and every one is already "Free" for everyone, so there's no special USMCA rate to list. **Log it:** "USMCA flag is false only where the general rate is already Free; the effective USMCA duty is 0 either way."

---

## Task 9: Build `clean.trade`

*Log entries this uses: "Non-data rows," "All-zero rows," the trailing space in "Montserrat ," "2026 is a partial year."*

### 9.1 [PASTE + fill two blanks] Reshape years into rows

Right now each year is its own column. Dashboards need one row per year, with a single `yr` column and a single value column. This reshape is called **unpivoting**, and it's the most important step in this batch.

```sql
DROP TABLE IF EXISTS clean.trade;
CREATE TABLE clean.trade AS
SELECT ____                    AS country,      -- [YOUR TURN] fix "Montserrat "
       t.hts_number            AS hts10,
       LEFT(t.hts_number, 8)   AS hts8,
       t.description,
       v.yr,
       v.is_partial,
       v.customs_value
FROM raw.dataweb_imports t
CROSS JOIN LATERAL (VALUES
    (2019, false, t.y2019::numeric),
    (2020, false, t.y2020::numeric),
    (2021, false, t.y2021::numeric),
    (2022, false, t.y2022::numeric),
    (2023, false, t.y2023::numeric),
    (2024, false, t.y2024::numeric),
    (2025, false, t.y2025::numeric),
    (2026, true,  t.y2026_jan_aug::numeric)
) AS v(yr, is_partial, customs_value)
WHERE ____;                                     -- [YOUR TURN] two conditions
```

**What's new: `CROSS JOIN LATERAL (VALUES ...)`.** For each raw row, this creates 8 rows, one per year. Each new row holds the year, a true/false partial-year flag, and that year's value. Read it as: "for every row in t, attach these 8 little rows." One wide row with 8 year columns becomes 8 narrow rows.

**Your two blanks:**
1. **`country`:** use the function that strips leading and trailing spaces (see your cheat sheet).
2. **`WHERE`:** keep only real trade rows (Batch 1, 4.1), **and** only rows where `customs_value` isn't zero.

**Why drop zero values here?** In a long table, a missing row already means "no trade that year," so zero rows are just clutter. This one condition also removes the 8 all-zero rows from 4.4, because all 8 of their year-rows are zero. Note that in the log as the decision for that entry.

**`is_partial`** carries your 4.6 decision into the data itself. In Batch 3, any year-over-year chart can filter on `is_partial = false`, or label 2026 as partial.

### 9.2 [YOUR TURN] Check it

Count the rows, the distinct countries and the distinct `hts10` codes in `clean.trade`.
**Expect:** 14,673 rows, 178 countries and 58 codes.

Two questions to answer in the log:
- Why 178 countries and not 179? (You've seen this before.)
- Did trimming merge "Montserrat " with an existing "Montserrat"? Check with `WHERE country LIKE 'Montserrat%'`.

---

## Task 10: Build `clean.trade_rated`

*Log entries this uses: "Neither join works alone" (7.3).*

### 10.1 [YOUR TURN] Write the join

You've already worked out the join condition: match on the full 10-digit code **or** the 8-digit parent. Fill in the `ON`:

```sql
DROP TABLE IF EXISTS clean.trade_rated;
CREATE TABLE clean.trade_rated AS
SELECT t.*,
       r.hts_code     AS rate_line,
       r.general_rate,
       r.usmca_free
FROM clean.trade t
LEFT JOIN clean.hts_rates r
       ON ____;          -- [YOUR TURN] 10-digit match OR 8-digit match
```

`t.*` means "every column from `t`." You'll want `hts10` and `hts8` from `t`, and `hts_code` from `r`.

**Why this join is now safe:** in 7.3, a trade code could match both its own row (with a blank rate) and its parent row (with the rate), which would create duplicates. `clean.hts_rates` only contains rows that carry a rate, so every trade code now matches exactly one line. Task 10.2 proves that.

### 10.2 [YOUR TURN] Prove it

Write checks that answer three questions:
1. Does `clean.trade_rated` have the **same number of rows** as `clean.trade`? If it has more, some codes matched twice.
2. How many rows have no rate line, where `rate_line IS NULL`? (This is your anti-join from 7.2.)
3. How many rows have a NULL `general_rate`?

**Expect:** 14,673 = 14,673, then 0, then 0.

These checks are what make the join trustworthy. Save them in the file next to the build.

---

## Task 11: Reconcile to the source

### 11.1 [YOUR TURN] Do the totals still match?

The raw file's **Total row** is an independent control total, published by DataWeb itself. If your clean tables are right, they should add back to it exactly.

1. Write a query that sums `customs_value` by `yr` from `clean.trade_rated`.
2. Write a query that shows the Total row from `raw.dataweb_imports` (hint: filter on `data_type`).
3. Compare them year by year.

**Expect:** an exact match in all 8 years, for example 2019 = 9,627,505,157.

**Log it under Validation notes.** "Clean table reconciles to the DataWeb control total in every year" is one of the strongest lines you can put in a portfolio README. It proves that removing junk rows, dropping zeros, trimming and reshaping lost nothing.

---

## Closing the open log items

Update these Decisions in your log before you call Batch 2 done:

| Log entry | Decision |
|---|---|
| Non-data rows | Filtered in `clean.trade` (`data_type = 'Customs Value'`) |
| All-zero rows | Removed by dropping zero values in the long table |
| Trailing space ("Montserrat ") | `TRIM()` in `clean.trade` |
| Blanks vs. NULLs | `NULLIF()` in `clean.hts_rates` |
| Casting general rate | `CASE` in `clean.hts_rates`; stored as a decimal (6.1% = 0.061) |
| Duty rates on 8-digit line + neither join alone | 10-digit OR 8-digit join in `clean.trade_rated`, verified with 0 orphans and 0 duplicates |
| USMCA indicator | Exact-match regex; flag in `clean.hts_rates` |
| 2026 partial year | `is_partial` flag in `clean.trade` |
| Code splits | `hts8` column in `clean.trade` for trend charts |
| Descriptions out of context | Use the trade-file `description` column for display |
| Row order in the schedule | **No longer needed.** Rates are looked up by code, not by position, and display names come from the trade file. Close it with that reasoning. |
| Hong Kong / Macau | **Still open.** Resolve when building the tariff layer in Batch 3. |

---

## Done when

- [ ] Three clean tables are built, each from a saved `.sql` file that reruns cleanly
- [ ] All checks in 8.2, 9.2 and 10.2 match the expected results
- [ ] Totals reconcile to the Total row in all 8 years
- [ ] Every log entry has a Decision, or is explicitly marked open
