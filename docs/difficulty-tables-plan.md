## Goal

Move difficulty values out of `chartdiffs` columns and blobs into dedicated tables, so that:

- every calculator's value at every rate can be filtered and sorted in SQL;
- charts can be filtered by their top and second pattern;
- new calculators (including user-defined ones) can be added without schema migrations;
- storage stays compact on large libraries.

minacalc is expected to be removed from the game, so its per-skillset values are not stored or made filterable. Patterns will come from our own pattern analyzer. It describes the chart rather than rating its difficulty.

## Current State

`chartdiffs` (`rizu/library/sql/migrate5.sql`) is keyed by `(hash, index, modifiers, rate, mode, custom_user_id)` and stores:

- `enps_diff`, `osu_diff`, `msd_diff` as indexed `REAL` scalars;
- `msd_diff_data` (skillsets at the chart's own rate) and `msd_diff_rates` (overall at each rate) as `BLOB`s.

The blobs can't be queried, and each new calculator means adding another column.

## Design

Use two tables:

- **A generic difficulty table** for every calculator: MSD overall, osu, ENPS and custom calculators.
- **A pattern table** for the pattern analyzer's top and second pattern.

Both tables follow these rules:

- **Charts** are referenced by `chartmetas.id` (unique on `(hash, index)`), not by the hash text. The difficulty table can reach ~100 rows per chart, so repeating a 32+ character hash in every row would bloat the table and its indexes.
- **Scope:** both tables describe the **unmodded** chart. Modded or otherwise non-standard play keeps using `chartdiffs`. The same value must not be stored in both places.

### Calculator Registry

```sql
CREATE TABLE calculators (
	`id` INTEGER PRIMARY KEY,
	`name` TEXT NOT NULL UNIQUE,  -- 'msd', 'osu', 'enps', 'patterns', 'custom:foo'
	`version` INTEGER NOT NULL,
	`custom_user_id` INTEGER      -- set for per-user custom calculators
);
```

The pattern analyzer is registered here too, so its version is tracked the same way. `custom_user_id` lives here, not on every difficulty row.

### Difficulty Table

```sql
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

- **Values** are `INTEGER` in centi-units (`2534` = 25.34). SQLite stores small integers in 1–8 bytes, so a typical value takes 2 bytes plus a 1-byte header. A `REAL` always takes 8. Integers also give exact equality and stable sorting.
- **Rate** is its own `INTEGER` column, never part of an enum name. Store it the same way `chartdiffs.rate` does. osu HT/DT is `rate = 0.75 / 1.5`, not `OSU_HALF_TIME_DIFF`.
- Removing a calculator, or invalidating it after a version bump, is a single `DELETE FROM chart_difficulties WHERE calc_id = ?`.

### Pattern Table

```sql
CREATE TABLE chart_patterns (
	`chart_id` INTEGER NOT NULL,
	`analyzer_id` INTEGER NOT NULL,  -- calculators.id
	`top_pattern` INTEGER NOT NULL,
	`second_pattern` INTEGER,        -- NULL when the analyzer finds only one pattern
	PRIMARY KEY (`chart_id`, `analyzer_id`)
) WITHOUT ROWID;

CREATE INDEX chart_patterns_top_idx ON chart_patterns (`analyzer_id`, `top_pattern`);
CREATE INDEX chart_patterns_second_idx ON chart_patterns (`analyzer_id`, `second_pattern`);
```

- **No rate column.** Rate makes a chart faster, but it doesn't change the patterns the player plays. minacalc reports different skillsets per rate because it rates speed, which is the calculator's job and not the analyzer's.
- **Stamina is a pattern**, alongside speed, jack and technical.

#### Pattern IDs

The analyzer reports an abstract category, or a specific pattern when it is fully confident. IDs are allocated in blocks of 16 per category, so that filtering by a category also matches its specific patterns and stays an index range scan:

| ID | Pattern |
|---|---|
| 16 | speed (unspecified) |
| 32 | stamina (unspecified) |
| 48 | jack (unspecified) |
| 49 | chordjack |
| 50 | jackspeed |
| 64 | technical (unspecified) |

The specific patterns above are examples. The final list is up to the analyzer.

- Category: `top_pattern BETWEEN 48 AND 63` matches any jack.
- Exact: `top_pattern = 49` matches chordjack only.
- Top or second: `top_pattern BETWEEN 48 AND 63 OR second_pattern BETWEEN 48 AND 63`, which can use both indexes.
- A new specific pattern takes a free slot in its block without a migration. Values up to 127 take 1 byte, which allows 7 categories with 15 specific patterns each. Past that, widen the blocks and accept 2 bytes per value.
- IDs are stored and must never be reused or renumbered. Retire an ID instead, and bump the analyzer version if old rows have to be recomputed.

## Query Layer

The UI should see one "difficulty source" identifier, such as `msd`, `osu`, `enps` or `custom:foo`, plus a rate. Pattern filters take a pattern or category, and whether it should match the top pattern only or top or second. `ChartviewsRepo` and `QueryFragments` map these to the right table and join. Filter and sort code must not branch on which table backs a source.

## Migration

1. Add `calculators`, `chart_difficulties` and `chart_patterns`, and seed `calculators` with `msd`, `osu` and `enps`.
2. Fill `chart_difficulties` from the calculators during chartdiff computation. Backfill existing charts.
3. Point library filters and sorts at the new tables through the query layer.
4. Measure sort and filter performance on a large library. Sorting by osu/ENPS/MSD now needs a join, where before it used a `chartdiffs` column.
5. Remove `enps_diff`, `osu_diff`, `msd_diff_data` and `msd_diff_rates` from `chartdiffs` once nothing reads them. Keep `msd_diff` only if modded plays still need a scalar.
6. When the pattern analyzer lands, register it in `calculators` and fill `chart_patterns`. minacalc skillsets are not mapped onto pattern IDs, since they don't match the analyzer's categories.

## Open Questions

- Should `chart_difficulties` and `chart_patterns` rows be removed when their `chartmetas` row is deleted or recreated? `chartmetas.id` stability needs checking.
- Should `chartdiffs` keep `osu_diff` and `enps_diff` for modded charts, or recompute them on demand?
- Which modifiers change patterns (random, no long notes) and which don't (mirror)? Patterns of modded charts could be shown for the latter without recomputing.
