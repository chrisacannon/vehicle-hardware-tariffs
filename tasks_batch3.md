# Batch 3: Vehicle Hardware — Who's Exposed, Who Gains

**The question this batch answers:** *Tariffs are reshuffling where vehicle hardware comes from. Who's exposed, and who gains?*

**Scope:** locks, hinges and fittings made for motor vehicles, the hardware that goes into cars, trucks and heavy equipment.

**What you'll have at the end:**
- **Page 1, "Where it comes from":** import value and share by origin, 2019–2026, USMCA vs. China vs. rest of world.
- **Page 2, "What it costs":** estimated duty burden by origin, built on a sourced rate table you research yourself.

**Same markers as Batch 2:** **[PASTE]** means run as given, with any new concept explained. **[YOUR TURN]** means you write it. **Expect:** is the result to check against.

**Log rule:** after each task, send me one rough line in your own words. I'll format it.

| File | What goes in it |
|---|---|
| `11_build_vehicle_hw.sql` | Task 12 |
| `12_origin_shares.sql` | Task 13 |
| `data/tariff_layers.csv` + `13_base_rates.sql` | Task 14 |
| `14_duty_estimate.sql` | Task 15 |

---

## Task 12: Define the segment

### 12.1 [YOUR TURN] Find the motor-vehicle codes

Write a query that lists the distinct `hts10` and `description` from `clean.trade` where the description mentions motor vehicles. Use `ILIKE` (case-insensitive) with the pattern `'%motor veh%'`.

**Expect:** 6 codes. **But one of them doesn't belong.** Read all six descriptions carefully and find the one that's a trap. Then send me your rough line: which code, and why a text search alone wasn't enough.

### 12.2 [PASTE] Build the segment table

```sql
DROP TABLE IF EXISTS clean.vehicle_hw;
CREATE TABLE clean.vehicle_hw AS
SELECT tr.*,
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
FROM clean.trade_rated tr
WHERE hts10 IN ('8301200030', '8301200060', '8302103000',
                '8302303010', '8302303060', '8302306000');
```

**What's new:** nothing, really. These are two `CASE` statements like 8.1, used here to **label** rows rather than convert them. `product_group` turns codes into names a salesperson would use. `origin_group` puts countries into the buckets the story needs.

**Why list the codes explicitly** instead of reusing the `ILIKE` filter? Because 12.1 showed that a text search catches something it shouldn't. An explicit list is a deliberate scope decision you can defend.

### 12.3 [YOUR TURN] Check it

Count the rows, count the distinct `hts10` codes, and sum `customs_value` for `yr = 2025`.
**Expect:** 1,688 rows, 6 codes, and about **$3.73 billion** in 2025.

---

## Task 13: Origin shares (Page 1)

### 13.1 [PASTE] Share of each origin, by year

```sql
SELECT yr,
       origin_group,
       ROUND(SUM(customs_value) / 1e6, 1) AS value_m,
       ROUND(100 * SUM(customs_value)
                 / SUM(SUM(customs_value)) OVER (PARTITION BY yr), 1) AS share_pct
FROM clean.vehicle_hw
WHERE yr IN (2019, 2025)
GROUP BY yr, origin_group
ORDER BY yr, value_m DESC;
```

**New concept: the window function `SUM(...) OVER (PARTITION BY yr)`.** Normally a `SUM` with `GROUP BY` collapses rows into one total per group. A window function computes a total *alongside* each row without collapsing anything. Here, `SUM(SUM(customs_value)) OVER (PARTITION BY yr)` means "for each row, also give me the grand total for that row's year." Dividing each origin's value by its year's total gives its share.

Read it inside-out:
- the inner `SUM(customs_value)` is each origin's total, from the `GROUP BY`;
- the outer `SUM(...) OVER (PARTITION BY yr)` adds those origin totals up within each year.

Window functions come up often in SQL interviews, so this is worth understanding properly. Ask if it doesn't click.

**Expect:**
| Origin | 2019 share | 2025 share |
|---|---|---|
| USMCA (Mexico, Canada) | 47.6% | 50.0% |
| Rest of world | 35.6% | 37.8% |
| China | 16.9% | 12.2% |
| Hong Kong / Macau | 0.0% | 0.0% |

### 13.2 [YOUR TURN] Drill into "Rest of world"

"Rest of world" is 38% of the segment, and it hides who's actually in it. Write a query listing the **top 10 countries by 2025 value** in `clean.vehicle_hw`, with their values in millions.
**Expect:** Mexico, Canada, China, then South Korea and Japan close together at about $350–370M each.

Your rough line for the log should say what story these numbers tell. Think about China's direction, USMCA's direction, and where Korea and Japan fit.

### 13.3 Close D4 (Hong Kong / Macau)

Look at the Hong Kong / Macau row in 13.1. Is it material to this segment? Send me one line on what you'd decide, and why. That closes the last open item from Batch 1.

---

## Task 14: Tariff rates (Page 2)

**What this task is for:** a small, sourced table of the tariff rules that apply to these parts, so Page 2's numbers can be traced to official documents.

**What matters and what doesn't:** only rules that change the Page 2 numbers need to be verified. Rules that don't affect the model are recorded with a note but not chased (see "Method rules" in `findings.md`).

**Done when:** checks 14.1 and 14.2 are marked `verified = yes` in `data/tariff_layers.csv`.

The rate table is already drafted in `data/tariff_layers.csv`. Each row has a source, a confidence level, and a note.

### 14.1 Check: USMCA-qualifying parts are exempt ✔ (done)
- **Open:** Proclamation 10908, the auto parts tariff (presidency.ucsb.edu, "Proclamation 10908—Adjusting Imports of Automobiles and Automobile Parts")
- **Ctrl+F:** `qualify for preferential treatment`
- **You should see clause (4):** the 25% tariff "shall not apply to automobile parts that qualify for preferential treatment under the USMCA" until a process to tax only non-U.S. content is published.
- **Then:** row 1 → `verified = yes`; put this link in `source_url`.

### 14.2 Check: your codes are on the auto-parts list ✔ (done)
- **Open:** the CBP Automobile Parts HTS List (link in row 4). CBP is the agency that collects tariffs at the border; this list is the set of codes the auto-parts tariff applies to.
- **Ctrl+F:** `8302.10.30`, then `8301.20`, then `8302.30`
- **You should see:** all three. (`8302.30` covers both of your 8302.30 rate lines.)
- **Then:** row 4 → `verified = yes`; put this link in `source_url`.

### 14.3 The model: three tiers

| Tier | Origins | Estimated tariff | Confidence |
|---|---|---|---|
| USMCA | Mexico, Canada | 0% | verified (14.1, 14.2) |
| Trade-deal partner | Japan, South Korea, Taiwan, EU members (UK at 10%) | 15% | estimate (secondary source), footnoted |
| All other origins | everyone else, including China | base duty + 25% | verified (14.2) |

**Deliberately left out, and why:**
- **China's legacy Section 301 duties:** they can only *add* to China's rate. Leaving them out understates China's burden; it can't change the conclusion. Footnote: "China may owe additional Section 301 duties; its estimate is a floor."
- **IEEPA tariffs** (struck down Feb 2026), **the Section 122 surcharge** (expired Jul 2026), **the 2026 Section 301 action**, and **steel/aluminum derivatives**: recorded in the table, but they don't apply to these parts as vehicle parts, or are no longer in force.

---

## Task 15: Estimated tariff burden (Page 2)

**What this task is for:** apply the three tiers to 2025 imports, answering *"what would 2025's imports owe under today's tariff rules?"*

**Done when:** the table builds, every row has a rate, and the tier summary matches the expected values below.

### 15.1 [PASTE] Build the estimate

```sql
DROP TABLE IF EXISTS clean.vehicle_duty_est;
CREATE TABLE clean.vehicle_duty_est AS
WITH tiered AS (
    SELECT *,
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
    FROM clean.vehicle_hw
    WHERE yr = 2025
)
SELECT *,
       CASE
         WHEN tariff_tier = 'USMCA'              THEN 0
         WHEN country = 'United Kingdom'         THEN 0.10
         WHEN tariff_tier = 'Trade-deal partner' THEN 0.15
         ELSE general_rate + 0.25
       END AS est_tariff_rate
FROM tiered;
```

**What's new:** nothing. It's a CTE (Task 11) feeding two `CASE` statements (Task 12). The first assigns each country a tier; the second assigns the rate. Note the order inside the second `CASE`: the UK line comes before the general deal-partner line, because `CASE` stops at the first match.

### 15.2 [YOUR TURN] Check it

1. Count the rows, and count rows where `est_tariff_rate IS NULL`. **Expect:** 221 and 0.
2. Summarize by `tariff_tier`: total value, total estimated tariff (`SUM(customs_value * est_tariff_rate)`), and the effective rate (tariff ÷ value). **Expect:**

| Tier | 2025 value | Est. tariff | Effective rate |
|---|---|---|---|
| USMCA | $1,863.9M | $0 | 0.0% |
| Trade-deal partner | $1,110.1M | $165.7M | 14.9% |
| All other origins | $752.9M | $206.8M | 27.5% |

**The headline for Page 2:** Mexico and Canada supply half the market at 0%; China is at about 27% even before any Section 301 duties.

---

## Task 16: Power BI

**What this task is for:** turn Tasks 13 and 15 into two dashboard pages a salesperson could use.

**Done when:** both pages are built, and the numbers on them match your SQL results from 13.1 and 15.2.

**Keep in mind:** SQL produces plain numbers; Power BI does the formatting ($, M, %). That's the split from Task 15.

### 16.1 Connect to Postgres
1. Power BI Desktop → **Get Data** → **PostgreSQL database**.
2. Server: `localhost` · Database: `tariff_demo` · Data connectivity mode: **Import**.
3. Sign in with **Database** credentials (the `postgres` user and your password).
4. In the Navigator, tick **clean.vehicle_hw** and **clean.vehicle_duty_est** → **Load**.

If Power BI says a PostgreSQL provider is missing, it needs the Npgsql driver; send me the exact message.

### 16.2 Measures (DAX)
Create these in the **vehicle_hw** table:
```
Total Value  = SUM ( vehicle_hw[customs_value] )

Origin Share =
DIVIDE (
    [Total Value],
    CALCULATE ( [Total Value],
        REMOVEFILTERS ( vehicle_hw[origin_group], vehicle_hw[Origin (chart)], vehicle_hw[country] ) )
)

Share 2019 =
CALCULATE ( [Origin Share], vehicle_hw[yr] = 2019, REMOVEFILTERS ( vehicle_hw[Year Label] ) )

Share Change (pts) = ( [Origin Share] - [Share 2019] ) * 100

Share vs 2019 =
VAR chg = [Share Change (pts)]
RETURN IF ( chg >= 0, "▲ ", "▼ " ) & FORMAT ( ABS ( chg ), "0.0" ) & " pts vs 2019"

Import Value Label = "$" & FORMAT ( [Total Value] / 1e6, "#,0.0" ) & "M"

Imports Label = "$" & FORMAT ( [Total Value] / 1e9, "0.00" ) & "B"
```
`Import Value Label` is a text measure for the share chart's tooltip. The chart applied its percentage format to the tooltip's dollar value, and a text value can't be reformatted. `Imports Label` does the same job for Card 1 ($3.73B): a text value isn't affected by format strings or display units.
And two calculated columns in **vehicle_hw** (right-click the table → New column):
```
Year Label     = IF ( vehicle_hw[yr] = 2026, "2026 (Jan–Aug)", FORMAT ( vehicle_hw[yr], "0" ) )
Origin (chart) = IF ( vehicle_hw[origin_group] = "Hong Kong / Macau", "Rest of world", vehicle_hw[origin_group] )
```
Select **Year Label** → Column tools → **Sort by column → yr**. `Origin (chart)` folds Hong Kong/Macau (<0.1%, too thin to see) into Rest of world for display only; the tables are unchanged.
And these in **vehicle_duty_est**:
```
Import Value   = SUM ( vehicle_duty_est[customs_value] )
Est Tariff     = SUMX ( vehicle_duty_est, vehicle_duty_est[customs_value] * vehicle_duty_est[est_tariff_rate] )
Effective Rate = DIVIDE ( [Est Tariff], [Import Value] )

Country Bar Color = IF ( SELECTEDVALUE ( vehicle_duty_est[country] ) = "China", "#C8553D", "#A0A8B0" )
```
In Power BI the table names include the schema, e.g. `'clean vehicle_duty_est'[country]`; use the name as it appears in your Data pane.
`Origin Share` is the DAX version of the 13.1 window function: `REMOVEFILTERS(...)` drops any origin or country filter to get the year's total, just like `OVER (PARTITION BY yr)`. It names all three origin-type columns so a card filtered on any of them still divides by the full year. `Effective Rate` is the same value-weighted rate as 15.2.

Format `Origin Share` and `Effective Rate` as percentages with **1 decimal place**. Format `Import Value` and `Est Tariff` as currency in millions: Model view → select the measure → Properties → Formatting → Format **Custom** → `$#,0,,.0"M"`. The two "divide by 1,000" commas go **before** the decimal point; after it, they print as text. Leave `Total Value` as **Currency**; its displays are handled by `Imports Label`, the tooltip label and chart display units.

### 16.3 Theme, canvas and layout (both pages)
- **Canvas:** click empty canvas → Format page → Canvas settings → **16:9 (1280 × 720)**.
- **Theme:** save `tariff_theme.json` in the project folder → **View → Themes → dropdown arrow → Browse for themes** → select it. It sets the colors and fonts for every visual. Anything formatted by hand earlier keeps its manual setting; use **Reset to default** in that visual's Format pane to pick up the theme.
- **Text boxes ignore themes.** Format their text directly: title Segoe UI Semibold 20pt `#333333`; subtitle Segoe UI 12pt `#555555`; footnote Segoe UI 9pt `#555555`.
- **Colors (both pages):** USMCA `#2F6DB5` blue · China `#C8553D` orange · Trade-deal partner `#4A9A9A` teal · Rest of world / All other origins `#A0A8B0` gray.
- **Chart titles:** type them in Format visual → General → Title → **Text**, and turn **Subtitle** off. If the text is left blank, Power BI builds a title from the field names.
- **Field labels:** use **Rename for this visual** in the field well for data labels (they appear in tooltips), never for chart titles.
- **Position visuals by number:** select the visual → Format visual → General → Properties → **Size and position**. Margins are 20px; gaps are 16px. If a visual goes missing off-canvas, find it in **View → Selection**.

### 16.4 Page 1: "Where it comes from"

**Title:** Mexico and Canada supply half of U.S. vehicle hardware imports, and China's share is shrinking
**Subtitle:** Locks, hinges and fittings for motor vehicles, U.S. imports 2019–2026

| Element | X | Y | Width | Height |
|---|---|---|---|---|
| Title text box | 20 | 16 | 1240 | 40 |
| Subtitle text box | 20 | 56 | 1240 | 24 |
| Card 1: "Imports, 2025" | 20 | 96 | 298 | 90 |
| Card 2: "USMCA, 2025" | 334 | 96 | 298 | 90 |
| Card 3: "China, 2025" | 648 | 96 | 298 | 90 |
| Product slicer | 962 | 96 | 298 | 90 |
| Stacked column: "Share of import value by origin, 2019–2026" | 20 | 202 | 816 | 440 |
| Bar chart: "Top 10 supplier countries, 2025" | 852 | 202 | 408 | 440 |
| Footnote text box | 20 | 656 | 1240 | 44 |

- **Stacked column** (regular stacked, not 100% stacked): X-axis `Year Label`, Y-axis `Origin Share` renamed **Share of imports**, legend `Origin (chart)`. Tooltips well: `Import Value Label` renamed **Import value**. Each column sums to 100%, so the axis runs 0–100% on its own. (A 100% stacked chart on `Total Value` adds its own unformattable 2-decimal share to the tooltip.)
- **Bar chart:** `country` by `Total Value` (renamed **Import value**), visual filter `yr` = 2025, Top N = 10. Data labels on, display units **Millions**, 1 decimal; X-axis off (the labels replace it).
- **Card 1:** `Imports Label`, visual filter `yr` = 2025, label **Imports, 2025**. Shows $3.73B: the headline in billions, the detail elsewhere in millions.
- **Cards 2 and 3:** `Origin Share`, visual filters `yr` = 2025 and `Origin (chart)` = USMCA (Mexico, Canada) / China. Labels **USMCA, 2025** and **China, 2025** (the year matters because the chart below spans 2019–2026; "share" is dropped to fit, since the % says it). Add `Share vs 2019` as the card's reference label (Format visual → Reference labels → add data). **Filter on `yr`, not `Year Label`.** Expect 50.0% ▲ 2.4 pts and 12.2% ▼ 4.7 pts.
- **Card formatting (as built):**
  - Cards → Layout → **Arrangement: Horizontal** (reference label beside the number, not below it).
  - Cards → **Divider: off**.
  - Reference labels → Layout → **top padding** to center the label vertically (13px on the USMCA card, 18px on China; there is no vertical alignment option).
  - Reference label text: Segoe UI regular, **11pt** (largest that fits without cutting off).
  - Reference label color: Value → Color → **fx** → Rules on `Share Change (pts)`: ≥ 0 → green `#2E7D32`; < 0 → red `#C62828`.
  - Center the callout value and category label; copy across with the Format painter.

**Footnote text:**
> Source: U.S. International Trade Commission (USITC) DataWeb, U.S. imports for consumption, customs value. Products: HTS 8301.20, 8302.10.30 and 8302.30 (locks, hinges, and fittings and mountings for motor vehicles). 2026 covers January–August only; shares within a year are comparable, but 2026 totals are not. Hong Kong/Macau (<0.1% of value) included in Rest of world.

### 16.5 Page 2: "What it costs"

**Setting up the page:**
- **Theme:** nothing to do. A theme applies to the whole report, so Page 2 already has it.
- **Canvas size is set per page.** On Page 2, click empty canvas → Format page → Canvas settings → confirm **16:9 (1280 × 720)**.
- **Text boxes:** copy the title, subtitle and footnote boxes from Page 1 (select → Ctrl+C → go to Page 2 → Ctrl+V). They paste in the same position with the same fonts; then just retype the text.
- **Formatting a chart:** set up the first chart, then use the **Format painter** (Home tab) to copy its look to the second.


**Title:** Mexico-sourced hardware enters at 0%; China-sourced pays at least 27%
**Subtitle:** Estimated tariff on 2025 imports under current rules

| Element | X | Y | Width | Height |
|---|---|---|---|---|
| Title text box | 20 | 16 | 1240 | 40 |
| Subtitle text box | 20 | 56 | 1240 | 24 |
| Bar chart: "Effective tariff rate by tier" | 20 | 96 | 612 | 330 |
| Bar chart: "Effective tariff rate, top 10 countries" | 648 | 96 | 612 | 330 |
| Table: tier, import value, est. tariff, effective rate | 20 | 442 | 816 | 200 |
| Assumptions text box | 852 | 442 | 408 | 200 |
| Footnote text box | 20 | 656 | 1240 | 44 |

- **No year filter on this page.** `vehicle_duty_est` holds 2025 only (15.1), and every field on Page 2 comes from that table.
- **Tier chart:** `Effective Rate` by `tariff_tier`. A single-measure chart uses only the theme's first color, so set each bar by hand: Bars → Colors → **Show all** → USMCA `#2F6DB5`, Trade-deal partner `#4A9A9A`, All other origins `#A0A8B0`. Data labels on, X-axis off.
- **Country chart:** `Effective Rate` by `country`. **Use `country` from `vehicle_duty_est`, not `vehicle_hw`**: the tables aren't related, so the wrong one shows every country at the overall ~10%, in alphabetical order. Filters pane → `country` → **Top N**, top 10 by `Import Value`. Sort: … → Sort axis → Effective Rate, Sort descending. Color: Bars → Colors → **fx** → Format style **Field value** → `Country Bar Color` (China orange, others gray). Data labels on, X-axis off.
- **Table:** `tariff_tier`, `Import Value`, `Est Tariff`, `Effective Rate`. Values and column headers **14pt**, Grid → Options → **Row padding 2px**, Totals on. Drag the column edges so the four columns fill the width.
- **Assumptions box:** heading Segoe UI Semibold 11pt; bullets Segoe UI 10pt `#333333`.

**Assumptions text:**
> **How to read this page**
> • Tariff rules as of October 2026, applied to 2025 import values.
> • All Mexico/Canada imports assumed to qualify for USMCA (0%).
> • Japan, South Korea, EU and Taiwan at 15%, UK at 10% (secondary source; not yet verified against the Federal Register).
> • Everyone else: base duty + 25% Section 232 auto/truck parts tariff.
> • China excludes legacy Section 301 duties, so its rate is a floor.
> • Hong Kong/Macau (<0.1%) not assigned China-specific tariffs.

**Footnote text:**
> Estimated tariff = 2025 import value × estimated tariff rate. Import data: USITC DataWeb. Rates and sources: data/tariff_layers.csv (Proclamation 10908; CBP Automobile Parts HTS List; medium/heavy-duty vehicle parts annex). Estimates for illustration, not for customs or pricing decisions.

### 16.6 [YOUR TURN] Reconcile the dashboard to SQL
Check that the Page 2 table shows the same three rows as your 15.2 result (USMCA $1,863.9M / 0.0%; deal partners $1,110.1M / 14.9%; all other $752.9M / 27.5%), and that Page 1's 2019 and 2025 shares match 13.1. Same habit as Task 11, applied to the dashboard. Send me one line when they match.
