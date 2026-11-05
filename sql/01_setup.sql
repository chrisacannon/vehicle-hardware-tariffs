-- 01_setup.sql
-- Purpose: create the two schemas the project uses.
--   raw = source files loaded exactly as downloaded, never edited
--   clean = every table built from raw, by the numbered files that follow
-- Run inside the tariff_demo database (created in pgAdmin beforehand).
-- Safe to rerun: IF NOT EXISTS skips a schema that's already there.

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS clean;