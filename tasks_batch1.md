# Batch 1 — Load and Profile

**Goal:** get both raw files into Postgres exactly as they came, then find out what's wrong with them. **You don't fix anything in this batch.** The fixes are batch 2, and they'll be better because you'll know the data first.

**Rules for the whole project**
- You write every query. Send me your query and its result, and I'll review it like a senior analyst would.
- If you're stuck for 20 minutes, ask me for a *hint*, not the answer.
- Every problem you find goes in `cleaning_log.md` (template at the bottom). That log is your interview material.

---

## Setup

1. Create a database called `tariff_demo`, with two schemas: `raw` for untouched data and `clean` for everything you build later.
2. Make a project folder with this layout:
   ```
   tariff_demo/
     data/raw/        <- the two source files, never edited
     sql/             <- one .sql file per task, numbered (01_create_raw_tables.sql, ...)
     cleaning_log.md
   ```
3. Optional: make it a git repo now. Commit after each task, so the history shows how the project was built.

---

## Task 1 — Convert the trade file to CSV, without "fixing" it

Open `DataWeb-Query-Export.xlsx` and go to the **Customs Value** sheet. Save it as CSV, as-is. Don't delete the title rows or the Total row, and don't reformat anything.

*Why:* every change to the data should be in SQL, where it can be repeated and explained. A cleanup done by hand in Excel is invisible.

## Task 2 — Load the trade file into a staging table

Create `raw.dataweb_imports` with one column per CSV column (12 of them), **all typed TEXT**. Load the CSV with pgAdmin's Import tool or with `\copy ... WITH (FORMAT csv)` in psql.

Be ready to answer this in an interview: *why load everything as TEXT first instead of NUMERIC and DATE?*

## Task 3 — Load the tariff schedule into a staging table

Same approach: create `raw.hts_schedule` with 9 TEXT columns and load `htsdata.csv`.

## Task 4 — Profile the trade table

Write a query that answers each question:

1. How many rows did you load? The file says "Data Row Count: 3141". Which rows account for the difference, and how would you filter them out?
2. How many distinct countries and distinct HTS codes are there?
3. Are all HTS codes exactly 10 characters? Are any stored with dots, spaces or a trailing `.0`?
4. How many rows are zero in every year? Keep them or drop them? Decide and justify.
5. Is every value in the "Country" column actually a country, or are any of them aggregates or regions?
6. The last column is January–August 2026. What does that mean for any year-over-year comparison you'd put on a dashboard?

## Task 5 — Profile the tariff schedule

1. How many rows have a blank HTS Number? What are those rows?
2. Which rows have a General Rate of Duty, and which are blank? Count the digits in each HTS code (ignoring the dots) and work out the pattern.
3. Using only what's in the file, what is the general duty rate for **8301.10.60.20**? Explain how you found it. This is the key insight of the batch.
4. The Special Rate column contains values like `Free (A+,AU,BH,CL,...)`. Which code in that list matters for Mexico and Canada? Look it up in the HTS General Notes rather than guessing, and write down where you found it.
5. List the different formats you see in the General Rate column, such as percentages, "Free", and compound rates. Which formats would break a simple cast to a number?

## Task 6 — Codes that change over time

1. Find HTS codes that have trade value in some years and exactly zero in all the others. In particular, look for codes that stop and codes that start.
2. Look closely at the **8301.10.60** family, and at **8301.60** and **8301.70** in the 2026 column. What happened?
3. If you charted 8301.60 imports from 2019 to 2026 without handling this, what would the chart wrongly show?

Write down what you think the fix is, but don't build it yet.

## Task 7 — Will the two tables join?

1. Normalize the HTS code in both tables to the same format, as a query rather than an update.
2. How many distinct trade codes find a 10-digit match in the schedule? Which ones don't match, and why?
3. For codes that match, where does the duty rate actually live? (See Task 5.3.)

---

## Done when

- [ ] Both raw tables are loaded, and the row counts are recorded in the log
- [ ] Each task has a saved `.sql` file:

  | File | What goes in it |
  |---|---|
  | `01_setup.sql` | `CREATE SCHEMA` lines |
  | `02_create_raw_tables.sql` | both `CREATE TABLE` blocks |
  | `03_profile_trade.sql` | Task 4 queries (4.1 through 4.6) |
  | `04_profile_schedule.sql` | Task 5 queries |
  | `05_code_changes.sql` | Task 6 queries |
  | `06_join_check.sql` | Task 7 queries |

- [ ] `cleaning_log.md` has an entry for every issue you found, which should be at least 6
- [ ] You've sent me your queries and results for review

---

## cleaning_log.md template

```
## [short name of issue]
- Table / column:
- What I found (with the query that shows it):
- Why it matters:
- Decision (fill in during batch 2):
```
