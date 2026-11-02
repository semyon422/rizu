-- Difficulty calculators added by plugins, see rizu.library.Calculators.
CREATE TABLE IF NOT EXISTS `calculators` (
	`id` INTEGER PRIMARY KEY,
	`name` TEXT NOT NULL UNIQUE,
	`version` INTEGER NOT NULL
);

-- Their values for unmodded charts, in hundredths. NULL when the calculator doesn't rate the chart.
CREATE TABLE IF NOT EXISTS `chart_difficulties` (
	`chart_id` INTEGER NOT NULL,
	`calc_id` INTEGER NOT NULL,
	`rate` INTEGER NOT NULL,
	`value` INTEGER,
	PRIMARY KEY (`chart_id`, `calc_id`, `rate`),
	FOREIGN KEY (chart_id) REFERENCES chartmetas(id) ON DELETE CASCADE,
	FOREIGN KEY (calc_id) REFERENCES calculators(id) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS chart_difficulties_sort_idx ON chart_difficulties (`calc_id`, `rate`, `value`);
