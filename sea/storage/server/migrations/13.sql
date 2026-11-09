-- MinaCalc is gone: leaderboards that rated by it (rating_calc 4) fall back to enps (2). enps_diff and osu_diff
-- move to chart_difficulties as the calculators enps and osu, and user_diff is gone. Their values are not copied:
-- the server computes them again.

UPDATE OR ROLLBACK leaderboards SET rating_calc = 2 WHERE rating_calc = 4;

DROP INDEX IF EXISTS chartdiffs_msd_idx;
ALTER TABLE chartdiffs DROP COLUMN msd_diff;
ALTER TABLE chartdiffs DROP COLUMN msd_diff_data;
ALTER TABLE chartdiffs DROP COLUMN msd_diff_rates;
ALTER TABLE chartplays DROP COLUMN rating_msd;

CREATE TABLE IF NOT EXISTS `calculators` (
	`id` INTEGER PRIMARY KEY,
	`name` TEXT NOT NULL UNIQUE,
	`version` INTEGER NOT NULL
);

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

DROP INDEX IF EXISTS chartdiffs_enps_idx;
DROP INDEX IF EXISTS chartdiffs_osu_idx;
DROP INDEX IF EXISTS chartdiffs_user_idx;
ALTER TABLE chartdiffs DROP COLUMN enps_diff;
ALTER TABLE chartdiffs DROP COLUMN osu_diff;
ALTER TABLE chartdiffs DROP COLUMN user_diff;
ALTER TABLE chartdiffs DROP COLUMN user_diff_data;
