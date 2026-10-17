## Goal

Move difficulty values out of `chartdiffs` columns and blobs into dedicated tables, so that:

- every Etterna skillset at every rate can be filtered and sorted in SQL;
- new calculators (including user-defined ones) can be added without schema migrations;
- storage stays compact on large libraries.

## Current State

`chartdiffs` (`rizu/library/sql/migrate5.sql`) is keyed by `(hash, index, modifiers, rate, mode, custom_user_id)` and stores:

- `enps_diff`, `osu_diff`, `msd_diff` as indexed `REAL` scalars;
- `msd_diff_data` (skillsets at the chart's own rate) and `msd_diff_rates` (overall at each rate) as `BLOB`s.

The blobs can't be queried, so filters like "stream 24–26 at 1.1x" aren't possible. Each new calculator also means adding another column.

## Design

Use a hybrid layout:

- **A wide table for MSD.** Its shape is fixed: 8 skillsets × 14 rates.
- **A narrow generic table for everything else.** That covers osu, ENPS and custom calculators.

Both tables follow these rules:

- **Values** are `INTEGER` in centi-units (`2534` = 25.34). SQLite stores small integers in 1–8 bytes, so a typical value takes 2 bytes plus a 1-byte header. A `REAL` always takes 8. Integers also give exact equality and stable sorting.
- **Rate** is its own `INTEGER` column, never part of an enum name. Store it the same way `chartdiffs.rate` does. osu HT/DT is `rate = 0.75 / 1.5`, not `OSU_HALF_TIME_DIFF`.
- **Charts** are referenced by `chartmetas.id` (unique on `(hash, index)`), not by the hash text. The narrow table can reach ~100 rows per chart, so repeating a 32+ character hash in every row would bloat the table and its indexes.
- **Scope:** both tables hold precomputed difficulty for the **unmodded** chart at every rate. Modded or otherwise non-standard play keeps using `chartdiffs`. The same value must not be stored in both places.

### MSD Table

```sql
CREATE TABLE chart_msd (
	`chart_id` INTEGER NOT NULL,
	`rate` INTEGER NOT NULL,
	`overall` INTEGER NOT NULL,
	`stream` INTEGER NOT NULL,
	`jumpstream` INTEGER NOT NULL,
	`handstream` INTEGER NOT NULL,
	`stamina` INTEGER NOT NULL,
	`jackspeed` INTEGER NOT NULL,
	`chordjack` INTEGER NOT NULL,
	`technical` INTEGER NOT NULL,
	PRIMARY KEY (`chart_id`, `rate`)
) WITHOUT ROWID;

CREATE INDEX chart_msd_overall_idx ON chart_msd (`rate`, `overall`);
-- add (rate, <skillset>) indexes for skillsets that get filtered on often
```

Estimated size: 100k charts × 14 rates ≈ 1.4M rows, about 40–50 MB including keys.

The minacalc version that produced the values should be recorded, either in a per-chart column or in a settings value. Then rows can be recomputed when minacalc changes.

### Generic Table

```sql
CREATE TABLE calculators (
	`id` INTEGER PRIMARY KEY,
	`name` TEXT NOT NULL UNIQUE,  -- 'osu', 'enps', 'custom:foo'
	`version` INTEGER NOT NULL,
	`custom_user_id` INTEGER      -- set for per-user custom calculators
);

CREATE TABLE chart_difficulties (
	`chart_id` INTEGER NOT NULL,
	`calc_id` INTEGER NOT NULL,
	`key` INTEGER NOT NULL DEFAULT 0,  -- sub-value for calculators with several outputs
	`rate` INTEGER NOT NULL,
	`value` INTEGER NOT NULL,          -- centi-units
	PRIMARY KEY (`chart_id`, `calc_id`, `key`, `rate`)
) WITHOUT ROWID;

CREATE INDEX chart_difficulties_sort_idx ON chart_difficulties (`calc_id`, `key`, `rate`, `value`);
```

- Removing a calculator, or invalidating it after a version bump, is a single `DELETE FROM chart_difficulties WHERE calc_id = ?`.
- `custom_user_id` lives on `calculators`, not on every difficulty row.

## Packed Encodings

All 8 skillsets fit in 128 bits (8 × uint16 centi-units, max 655.35). Don't use a 40.00 cap: high-rate charts go past it. SQLite integers are at most 64 bits, so storing this in the database means a `BLOB`, which brings back the unqueryable-blob problem. Use the packed form only where nothing is queried: network payloads and in-memory caches.

## Query Layer

The UI should see one "difficulty source" identifier, such as `msd.stream`, `msd.overall`, `osu` or `custom:foo`, plus a rate. `ChartviewsRepo` and `QueryFragments` map that source to the right table and join. Filter and sort code must not branch on which table backs a source.

## Migration

1. Add the new tables and the `calculators` registry, and seed it with `osu` and `enps`.
2. Fill `chart_msd` and `chart_difficulties` from the calculators during chartdiff computation. Backfill existing charts.
3. Point library filters and sorts at the new tables through the query layer.
4. Measure sort and filter performance on a large library. Sorting by osu/ENPS now needs a join, where before it used a `chartdiffs` column.
5. Remove `enps_diff`, `osu_diff`, `msd_diff_data` and `msd_diff_rates` from `chartdiffs` once nothing reads them. Keep `msd_diff` only if modded plays still need a scalar.

## Open Questions

- Should `chart_msd` and `chart_difficulties` rows be removed when their `chartmetas` row is deleted or recreated? `chartmetas.id` stability needs checking.
- Which skillsets get their own `(rate, skillset)` index, and which rely on a scan over `chart_msd`?
- Should `chartdiffs` keep `osu_diff` and `enps_diff` for modded charts, or recompute them on demand?
