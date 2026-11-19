# SQL Cheat Sheet — Batch 1 Patterns

## What this is for

Every SQL pattern you used in Batch 1, in one place, each with the real query you wrote. It has two jobs:

1. **Reference while you work.** When you're stuck in Batch 2, find the pattern that matches what you're trying to do, copy its shape, and change the table and column names. Look here before asking me. Most Batch 2 problems are a combination of these patterns.
2. **Practice from memory.** This is what makes syntax stick. See "How to practice" at the bottom. Fifteen minutes, a few times a week.

**How to read each entry:** *Use it when* tells you which situation calls for the pattern. **Shape** is the template. *Your example* is where you used it. *Gotcha* is the mistake that pattern invites.

---

## 1. Profiling: "what's actually in this column?"

### Count each distinct value
*Use it when:* you want to see every value in a column and how often each appears. It's the SQL version of an Excel filter dropdown, plus counts.
```sql
SELECT column, COUNT(*) AS row_count
FROM table
GROUP BY column
ORDER BY row_count DESC;
```
*Your example:* 4.1 found the junk rows by grouping on `data_type`. 5.5 found the rate formats by grouping on `general_rate`.

### Count distinct things
*Use it when:* you need "how many different ___ are there?"
```sql
SELECT COUNT(DISTINCT country)    AS countries,
       COUNT(DISTINCT hts_number) AS hts_codes
FROM raw.dataweb_imports
WHERE data_type = 'Customs Value';
```
*Your example:* 4.2 returned 179 countries and 58 codes.
*Gotcha:* without the `WHERE`, the junk rows get counted too.

### List distinct values, sorted
```sql
SELECT DISTINCT country
FROM raw.dataweb_imports
WHERE data_type = 'Customs Value'
ORDER BY country;
```
*Your example:* 4.5. Sorting made the list easy to scan, which is how the trailing space in "Montserrat " showed up.

### Check a format with a pattern (regex)
*Use it when:* you need to confirm that every value looks the way it should.
```sql
WHERE hts_number !~ '^[0-9]{10}$'   -- NOT exactly 10 digits
```
`~` means "matches" and `!~` means "doesn't match." `^` is the start, `$` is the end, and `[0-9]{10}` means ten digits.
*Your example:* 4.3.

### Count NULLs vs. blanks
*Use it when:* a column has empty-looking values and you need to know which kind they are.
```sql
SELECT column IS NULL AS is_null,
       column = ''    AS is_blank,
       COUNT(*)
FROM table
GROUP BY 1, 2;
```
*Gotcha:* `IS NULL` doesn't catch `''`. To catch both, write `WHERE column IS NULL OR column = ''`. In pgAdmin, NULL shows as a greyed-out `[null]` and a blank shows as an empty cell.

---

## 2. Filtering

### AND / OR, with parentheses
```sql
WHERE data_type = 'Customs Value'
  AND (y2019::numeric <> 0 OR y2020::numeric <> 0 OR ...)
```
*Gotcha:* SQL evaluates `AND` before `OR`. Without the parentheses, the `data_type` filter attaches only to the first condition, and the junk rows come back. **Whenever you mix AND with OR, use parentheses.**
*Your example:* the AND-vs-OR mistake in your Validation notes. AND meant "non-zero in every year" and returned 63 countries. OR meant "non-zero in any year" and returned 178.

### LIKE: simple text patterns
| Pattern | Matches |
|---|---|
| `LIKE '8301%'` | starts with 8301 |
| `LIKE '%Other%'` | contains "Other" anywhere |
| `LIKE '8301.__'` | "8301." followed by exactly two characters |

`%` matches any number of characters and `_` matches exactly one. `ILIKE` is the case-insensitive version.
*Gotcha:* `LIKE '%S%'` also matches "SG". Use it for prefixes. Be careful using it for codes buried inside lists.

---

## 3. Converting and cleaning values

| Function | What it does | Example |
|---|---|---|
| `::numeric` | text to number | `y2019::numeric` |
| `REPLACE(x, '.', '')` | remove or swap characters | `8301.10.60` becomes `83011060` |
| `LEFT(x, 8)` | first N characters | 10-digit code to its 8-digit parent |
| `LENGTH(x)` | number of characters | 4.3, 5.2 |
| `TRIM(x)` | strip leading and trailing spaces | the Batch 2 fix for "Montserrat " |
| `NULLIF(x, '')` | turn `''` into NULL | the Batch 2 fix for blanks |

*Gotcha:* `::numeric` fails on anything that isn't a clean number: commas (`9,627,505,157`), `%`, `Free`, or `''`. When a cast errors, the message names the value that broke it. Search for that value.

---

## 4. Aggregating: "add things up, then filter"

### SUM with GROUP BY
*Use it when:* you want totals per something, such as per code or per country.
```sql
SELECT hts_number,
       SUM(y2025::numeric) AS y2025
FROM raw.dataweb_imports
WHERE data_type = 'Customs Value'
GROUP BY hts_number;
```
**The rule:** every column in the `SELECT` must be either inside `SUM()`/`COUNT()` or listed in `GROUP BY`. Break it and you get the error *"must appear in the GROUP BY clause."*

### HAVING: filtering after grouping
*Use it when:* the condition is about a total, not a single row.
```sql
GROUP BY hts_number
HAVING SUM(y2025::numeric) > 0
```
`WHERE` filters rows **before** grouping, and `HAVING` filters groups **after**.

### Filtering one column, not the whole query
*Use it when:* you want several numbers side by side, but only one of them should be restricted, for example "all rows" next to "2025 only."
```sql
SELECT COUNT(*)                                     AS row_count,      -- all rows
       SUM(customs_value) FILTER (WHERE yr = 2025)  AS value_2025      -- 2025 only
FROM clean.vehicle_hw;
```
The same thing in a form that works in any database:
```sql
SUM(CASE WHEN yr = 2025 THEN customs_value ELSE 0 END) AS value_2025
```
**The rule:** `WHERE` filters the rows *before* anything is counted, so it affects every column. `FILTER` or `CASE` filters inside **one** aggregate.
*Your example:* 12.3. With `WHERE yr = 2025`, all three columns saw only 2025: 221 rows instead of 1,688.

### LEAST and GREATEST
`LEAST(a, b, c)` returns the smallest value and `GREATEST(a, b, c)` returns the largest. Since trade values are never negative:
- "Some year is zero" is `LEAST(...) = 0`.
- "Some year is non-zero" is `GREATEST(...) > 0`.

*Your example:* 6.1. It found the 7 codes that start or stop.

### Group by a derived value
```sql
SELECT LEFT(hts_number, 8) AS code_family, SUM(...)
...
GROUP BY LEFT(hts_number, 8);
```
*Your example:* 6.2b. Rolling codes up to their family showed that trade continued straight through each code split.

---

## 5. Joining two tables

### LEFT JOIN anti-join: "what has no match?"
*Use it when:* you need to check whether every row in table A finds a partner in table B.
```sql
SELECT DISTINCT t.hts_number
FROM raw.dataweb_imports t
LEFT JOIN raw.hts_schedule s
       ON t.hts_number = REPLACE(s.hts_number, '.', '')
WHERE t.data_type = 'Customs Value'
  AND s.hts_number IS NULL;
```
`LEFT JOIN` keeps every row from the left table. Where no match is found, the right table's columns come back NULL. Checking `IS NULL` on a right-table column finds exactly the rows that didn't match.
*Your example:* 7.2 returned 3 orphans.

### Joining on more than one possible match
```sql
ON t.hts_number = REPLACE(s.hts_number, '.', '')
OR LEFT(t.hts_number, 8) = REPLACE(s.hts_number, '.', '')
```
*Your example:* 7.3. Neither condition alone matched everything; together they left 0 orphans.

**The habit:** after any join, run the anti-join to count the orphans. Zero orphans means the join is complete.

---

## 6. Reading error messages

| The message says | Usually means |
|---|---|
| `column "x" does not exist` | typo, or the wrong column name. Check the Columns list in pgAdmin's left panel. |
| `invalid input syntax for type numeric: "..."` | a cast hit non-numeric text. The value in quotes is the culprit. |
| `must appear in the GROUP BY clause` | a selected column isn't summed or grouped. |
| `schema/relation "x" already exists` | you ran a CREATE twice. Highlight only the new lines before pressing F5. |

---

## How to practice (15 minutes, 2–3 times a week)

Retrieval practice, meaning writing from memory and then checking, is the fastest way to make syntax stick. Re-reading feels productive but doesn't work nearly as well.

1. **Cover the cheat sheet.** Open a blank Query Tool tab.
2. **Write one of the queries below from memory.** It's fine to struggle. The struggle is what does the work.
3. **Run it.** If it errors, use the error table above to fix it.
4. **Check it against your saved `.sql` file.** Note what you forgot.
5. **Next session, start with whatever you forgot.**

| Prompt | Pattern it drills | Check against |
|---|---|---|
| How many distinct countries and HTS codes are in the trade data? | COUNT DISTINCT + WHERE | 4.2 |
| Show every distinct General Rate value and how often it appears | GROUP BY + COUNT | 5.5 |
| Total 2025 imports per HTS code, largest first | SUM + GROUP BY + ORDER BY | (new: write it fresh) |
| Total trade per 8-digit code family, 2019 and 2025 | LEFT() + GROUP BY | 6.2b |
| Which trade codes have no match in the schedule? | LEFT JOIN anti-join | 7.2 |
| Which countries' names have leading or trailing spaces? | WHERE + TRIM comparison | (new: hint: `country <> TRIM(country)`) |

When you can write all six without looking, you've got Batch 1 down, and you'll be able to explain each one in an interview.
