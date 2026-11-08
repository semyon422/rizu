-- The few most significant patterns of a chartdiff, see rizu.library.repos.ChartPatternsRepo.
CREATE TABLE IF NOT EXISTS `chart_patterns` (
	`chartdiff_id` INTEGER NOT NULL,
	`rank` INTEGER NOT NULL,
	`pattern` TEXT NOT NULL,
	`share` REAL NOT NULL,
	`bpm` REAL,
	`version` INTEGER NOT NULL,
	PRIMARY KEY (`chartdiff_id`, `pattern`),
	FOREIGN KEY (`chartdiff_id`) REFERENCES chartdiffs(id) ON DELETE CASCADE
) WITHOUT ROWID;
