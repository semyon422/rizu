-- MinaCalc is gone, and so are the values it computed. Rizu Difficulty replaces user_diff.

DROP INDEX IF EXISTS chartdiffs_msd_idx;
ALTER TABLE chartdiffs DROP COLUMN msd_diff;
ALTER TABLE chartdiffs DROP COLUMN msd_diff_data;
ALTER TABLE chartdiffs DROP COLUMN msd_diff_rates;
ALTER TABLE chartplays DROP COLUMN rating_msd;

DROP INDEX IF EXISTS chartdiffs_user_idx;
ALTER TABLE chartdiffs DROP COLUMN user_diff;
ALTER TABLE chartdiffs DROP COLUMN user_diff_data;

-- Rizu Difficulty on the MSD scale. NULL for keymodes it does not rate.
ALTER TABLE chartdiffs ADD COLUMN rizu_diff REAL;
CREATE INDEX IF NOT EXISTS chartdiffs_rizu_idx ON chartdiffs (`rizu_diff`);

-- What a calculator rates a play, by calculator and value name: any values, any number of them.
CREATE TABLE IF NOT EXISTS `chartplay_ratings` (
	`chartplay_id` INTEGER NOT NULL,
	`calculator` TEXT NOT NULL,
	`key` TEXT NOT NULL,
	`value` REAL,
	PRIMARY KEY (`chartplay_id`, `calculator`, `key`),
	FOREIGN KEY (chartplay_id) REFERENCES chartplays(id) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS chartplay_ratings_sort_idx ON chartplay_ratings (`calculator`, `key`, `value`);

-- The top skillset and two most significant patterns of a chartdiff, made by chart.PatternDiffcalc.
ALTER TABLE chartdiffs ADD COLUMN skillset INTEGER;
ALTER TABLE chartdiffs ADD COLUMN pattern_1 INTEGER;
ALTER TABLE chartdiffs ADD COLUMN pattern_2 INTEGER;
ALTER TABLE chartdiffs ADD COLUMN pattern_share_1 REAL;
ALTER TABLE chartdiffs ADD COLUMN pattern_share_2 REAL;
ALTER TABLE chartdiffs ADD COLUMN pattern_bpm_1 REAL;
ALTER TABLE chartdiffs ADD COLUMN pattern_bpm_2 REAL;
