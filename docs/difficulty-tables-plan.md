# Difficulty storage

The difficulty values of a chart live in `chartdiffs` columns, one per calculator:

- `enps_diff`, the ENPS rating;
- `osu_diff`, the osu!mania star rating;
- `rizu_diff`, Rizu Difficulty on the MSD scale.

`select.diff_column` holds one of those columns directly, and `QueryFragments.getDifficultyField` prefixes it with `chartdiffs.`, so filtering and sorting need no join. `rizu_diff` is NULL for keymodes Rizu Difficulty does not rate.

The calculators are fixed parts of the game, `chart.EnpsDiffcalc`, `chart.OsuDiffcalc` and `chart.RizuDiffcalc`, run by `chart.DifficultyModel` together with the notes, preview and metadata diffcalcs. There is no plugin calculator registry and no generic per-chart difficulty table: a new calculator is a new column and a new diffcalc.

## Play ratings

`chartplay_ratings (chartplay_id, calculator, key, value)` stores what a calculator rates a play, one row per named value: `calculator` is its name, such as `"rizu"`, and `key` the value name, such as `"speed"`, `"stamina"`, `"chordjack"` or `"technical"`. It accepts any calculator and any number of values, unlike the fixed chart columns. The table has no writer yet; it is there for play rating systems.

## Patterns

The top skillset and the two most significant patterns live in `chartdiff` columns, made by `chart.PatternDiffcalc` from the chart notes and the labels of `chart.scoring.pattern_classifier`, alongside the other difficulties. `rizu.library.Library:getChartPatterns` reads them back for the UI. Bump `DifficultyModel.version` when any of them changes: at startup the library compares it with `scores.difficulty_version` and recomputes every chartdiff once.
