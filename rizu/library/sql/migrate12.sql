-- What every note of a chartplay did, as the score engine received it, to score it in other systems
-- without playing the replay again.
CREATE TABLE IF NOT EXISTS `chartplay_hits` (
	`chartplay_id` INTEGER PRIMARY KEY,
	`version` INTEGER NOT NULL,
	`notes_count` INTEGER NOT NULL,
	`inputmode` TEXT NOT NULL,
	`events` BLOB NOT NULL,
	FOREIGN KEY (chartplay_id) REFERENCES chartplays(id) ON DELETE CASCADE
);
