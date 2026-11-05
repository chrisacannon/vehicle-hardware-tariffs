-- 02_create_raw_tables.sql
-- Purpose: create empty tables for the two source files, then load them as-is.
-- Every column is TEXT on purpose: the data loads exactly as downloaded,
-- with nothing converted or rejected on the way in. Converting text to
-- numbers happens later in SQL (07, 08), where each step can be seen and rerun.
-- Load each CSV after running this file (pgAdmin: right-click table → Import/Export Data).

-- U.S. imports for consumption, customs value, by country and HTS code.
-- Source: USITC DataWeb export (Customs Value sheet saved as CSV, unedited).
-- One column per year; 2026 covers January–August only (log D5).
CREATE TABLE raw.dataweb_imports (
    data_type      TEXT,
    country        TEXT,
    hts_number     TEXT,
    description    TEXT,
    y2019          TEXT,
    y2020          TEXT,
    y2021          TEXT,
    y2022          TEXT,
    y2023          TEXT,
    y2024          TEXT,
    y2025          TEXT,
    y2026_jan_aug  TEXT
);

-- Harmonized Tariff Schedule (HTS) lines for chapters 8301–8302, with duty rates.
-- Source: USITC HTS export (htsdata.csv).
CREATE TABLE raw.hts_schedule (
    hts_number         TEXT,
    indent             TEXT,
    description        TEXT,
    unit_of_quantity   TEXT,
    general_rate       TEXT,
    special_rate       TEXT,
    column2_rate       TEXT,
    quota_quantity     TEXT,
    additional_duties  TEXT
);