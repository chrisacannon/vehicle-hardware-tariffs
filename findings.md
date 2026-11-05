# Findings — Vehicle Hardware Imports

What the data says, as distinct from the cleaning log, which records how the data was made trustworthy. Each finding names the query it comes from. These feed the README and the dashboard captions.

**Segment:** motor-vehicle locks, hinges, and fittings & mountings (6 HTS codes, see cleaning log D14). U.S. imports for consumption, customs value, USITC DataWeb. 2026 is January–August only.

## Method rules

- **A tariff is applied only where it's confirmed to apply** to that origin and code (verified on an official source). Nothing is assumed to apply by default.
- **When a choice can't change the result, pick the option with the fewest unverified assumptions, and state it.** Example: Hong Kong/Macau (under 0.1% of value) aren't assigned China-specific tariffs (cleaning log D4).

---

### F1. Who supplies the market (2025)
- **Source:** 12_origin_shares.sql (13.1, 13.2)
- Vehicle hardware imports totaled **$3.73B** in 2025.
- **Mexico and Canada lead, at half the market:** 50.0%, up from 47.6% in 2019.
- **China is a distant third and shrinking:** 12.2%, down from 16.9% in 2019.
- **Japan and South Korea** are next (about $350–370M each). Together they're about half of the rest of the world ($719M of $1.41B). The other half is spread across Germany, Taiwan, Turkey, India, Thailand and a long tail.

### F2. What it costs: estimated tariff by tier (2025 imports, current rules)
- **Source:** 14_duty_estimate.sql (15.2); rates in data/tariff_layers.csv
- **USMCA (Mexico, Canada): 0%** on $1,863.9M, half the market.
- **Trade-deal partners (Japan, Korea, EU, Taiwan; UK at 10%): 14.9%** on $1,110.1M, about $166M in estimated tariff.
- **All other origins, including China: 27.5%** on $752.9M, about $207M. China alone: 27.3%, a floor, since legacy Section 301 duties are excluded.
- **Reading it:** the tiers line up in reverse. The lower the tariff, the larger the share of the market. That's consistent with buyers favoring low-tariff sources, but the 2025 snapshot alone doesn't prove it: Mexico and Canada were already about 48% of the market in 2019, largely for proximity and long-standing USMCA supply chains. The stronger evidence is the *shift over time* in F1, with China falling from 16.9% to 12.2% as tariffs rose.
- **Rate vs. dollar exposure:** Thailand, India and Turkey carry higher effective rates than China (Thailand is highest at 29.3%), but their combined import value is still below China's, so China remains the larger tariff exposure in dollars. (Power BI Page 2, country chart)
- **Caveats:** current (2026) rules applied to the 2025 import mix; assumes all Mexico/Canada imports qualify for USMCA; the 15% deal-partner rate is from a secondary source.
