-- Difficulty calculators, their values for chartdiffs and plays, and the patterns of a chartdiff. Every value in
-- these tables is computed again, so development databases of the difficulty_rework branch with earlier forms of
-- them are not migrated.

DROP TABLE IF EXISTS `chartplay_ratings`;
DROP TABLE IF EXISTS `chart_difficulties`;
DROP TABLE IF EXISTS `calculators`;
DROP TABLE IF EXISTS `chart_patterns`;

-- MinaCalc is gone, and so are the values it computed.
DROP INDEX IF EXISTS chartdiffs_msd_idx;
ALTER TABLE chartdiffs DROP COLUMN msd_diff;
ALTER TABLE chartdiffs DROP COLUMN msd_diff_data;
ALTER TABLE chartdiffs DROP COLUMN msd_diff_rates;
ALTER TABLE chartplays DROP COLUMN rating_msd;

-- enps_diff and osu_diff move to chart_difficulties as the calculators enps and osu, user_diff is gone.
DROP INDEX IF EXISTS chartdiffs_enps_idx;
DROP INDEX IF EXISTS chartdiffs_osu_idx;
DROP INDEX IF EXISTS chartdiffs_user_idx;
ALTER TABLE chartdiffs DROP COLUMN enps_diff;
ALTER TABLE chartdiffs DROP COLUMN osu_diff;
ALTER TABLE chartdiffs DROP COLUMN user_diff;
ALTER TABLE chartdiffs DROP COLUMN user_diff_data;

-- Difficulty calculators added by plugins, see rizu.library.Calculators.
CREATE TABLE IF NOT EXISTS `calculators` (
	`id` INTEGER PRIMARY KEY,
	`name` TEXT NOT NULL UNIQUE,
	`version` INTEGER NOT NULL
);

-- Their values for chartdiffs, in hundredths. Key 0 is the headline, key i the calculator's keys[i].
-- NULL when the calculator does not rate the chart.
CREATE TABLE IF NOT EXISTS `chart_difficulties` (
	`chartdiff_id` INTEGER NOT NULL,
	`calc_id` INTEGER NOT NULL,
	`key` INTEGER NOT NULL,
	`value` INTEGER,
	PRIMARY KEY (`chartdiff_id`, `calc_id`, `key`),
	FOREIGN KEY (`chartdiff_id`) REFERENCES chartdiffs(id) ON DELETE CASCADE,
	FOREIGN KEY (`calc_id`) REFERENCES calculators(id) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS chart_difficulties_sort_idx ON chart_difficulties (`calc_id`, `key`, `value`);

-- Their values for plays, the same way.
CREATE TABLE IF NOT EXISTS `chartplay_ratings` (
	`chartplay_id` INTEGER NOT NULL,
	`calc_id` INTEGER NOT NULL,
	`key` INTEGER NOT NULL,
	`value` INTEGER,
	PRIMARY KEY (`chartplay_id`, `calc_id`, `key`),
	FOREIGN KEY (`chartplay_id`) REFERENCES chartplays(id) ON DELETE CASCADE,
	FOREIGN KEY (`calc_id`) REFERENCES calculators(id) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS chartplay_ratings_sort_idx ON chartplay_ratings (`calc_id`, `key`, `value`);

-- The top skillset and two most significant patterns of a chartdiff, see rizu.library.repos.ChartPatternsRepo.
CREATE TABLE IF NOT EXISTS `chart_patterns` (
	`chartdiff_id` INTEGER NOT NULL,
	`version` INTEGER NOT NULL,
	`skillset` INTEGER NOT NULL,
	`pattern_1` INTEGER NOT NULL,
	`pattern_2` INTEGER,
	`share_1` REAL NOT NULL,
	`share_2` REAL,
	`bpm_1` REAL,
	`bpm_2` REAL,
	PRIMARY KEY (`chartdiff_id`),
	FOREIGN KEY (`chartdiff_id`) REFERENCES chartdiffs(id) ON DELETE CASCADE
) WITHOUT ROWID;
