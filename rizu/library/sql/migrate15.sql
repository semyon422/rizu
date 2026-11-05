-- enps_diff and osu_diff move to chart_difficulties as the calculators enps and osu, user_diff is gone.
-- chart_difficulties is keyed by chartdiff now. The values are not copied: the calculators compute them again.
DROP TABLE chart_difficulties;

CREATE TABLE IF NOT EXISTS `chart_difficulties` (
	`chartdiff_id` INTEGER NOT NULL,
	`calc_id` INTEGER NOT NULL,
	`key` INTEGER NOT NULL,
	`value` INTEGER,
	PRIMARY KEY (`chartdiff_id`, `calc_id`, `key`),
	FOREIGN KEY (chartdiff_id) REFERENCES chartdiffs(id) ON DELETE CASCADE,
	FOREIGN KEY (calc_id) REFERENCES calculators(id) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS chart_difficulties_sort_idx ON chart_difficulties (`calc_id`, `key`, `value`);

DROP INDEX IF EXISTS chartdiffs_enps_idx;
DROP INDEX IF EXISTS chartdiffs_osu_idx;
DROP INDEX IF EXISTS chartdiffs_user_idx;
ALTER TABLE chartdiffs DROP COLUMN enps_diff;
ALTER TABLE chartdiffs DROP COLUMN osu_diff;
ALTER TABLE chartdiffs DROP COLUMN user_diff;
ALTER TABLE chartdiffs DROP COLUMN user_diff_data;
