-- Accuracies of a chartplay in other score systems. Normalscore stays in chartplays.accuracy.
CREATE TABLE IF NOT EXISTS `chartplay_accuracies` (
	`chartplay_id` INTEGER NOT NULL,
	`timings` INTEGER NOT NULL,
	`subtimings` INTEGER NOT NULL,
	`accuracy` REAL NOT NULL,
	PRIMARY KEY (`chartplay_id`, `timings`, `subtimings`),
	FOREIGN KEY (chartplay_id) REFERENCES chartplays(id) ON DELETE CASCADE
);
