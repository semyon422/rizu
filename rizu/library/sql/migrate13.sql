-- Development databases of the difficulty_rework branch had earlier forms of these tables. Every value
-- in them is computed again by the calculators.
DROP TABLE IF EXISTS `chartplay_ratings`;
DROP TABLE IF EXISTS `chart_difficulties`;
DROP TABLE IF EXISTS `calculators`;

-- Difficulty calculators added by plugins, see rizu.library.Calculators.
CREATE TABLE IF NOT EXISTS `calculators` (
	`id` INTEGER PRIMARY KEY,
	`name` TEXT NOT NULL UNIQUE,
	`version` INTEGER NOT NULL
);

-- Their values for unmodded charts, in hundredths. Key 0 is the headline, key i the calculator's keys[i].
-- NULL when the calculator does not rate the chart.
CREATE TABLE IF NOT EXISTS `chart_difficulties` (
	`chart_id` INTEGER NOT NULL,
	`calc_id` INTEGER NOT NULL,
	`key` INTEGER NOT NULL,
	`rate` INTEGER NOT NULL,
	`value` INTEGER,
	PRIMARY KEY (`chart_id`, `calc_id`, `key`, `rate`),
	FOREIGN KEY (chart_id) REFERENCES chartmetas(id) ON DELETE CASCADE,
	FOREIGN KEY (calc_id) REFERENCES calculators(id) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS chart_difficulties_sort_idx ON chart_difficulties (`calc_id`, `key`, `rate`, `value`);

-- Their values for plays, the same way.
CREATE TABLE IF NOT EXISTS `chartplay_ratings` (
	`chartplay_id` INTEGER NOT NULL,
	`calc_id` INTEGER NOT NULL,
	`key` INTEGER NOT NULL,
	`value` INTEGER,
	PRIMARY KEY (`chartplay_id`, `calc_id`, `key`),
	FOREIGN KEY (chartplay_id) REFERENCES chartplays(id) ON DELETE CASCADE,
	FOREIGN KEY (calc_id) REFERENCES calculators(id) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS chartplay_ratings_sort_idx ON chartplay_ratings (`calc_id`, `key`, `value`);
