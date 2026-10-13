-- A location with an url is remote: its charts are listed from a catalog and their files are downloaded when played.
ALTER TABLE locations ADD COLUMN url TEXT;

-- The files of a chart of a remote location, as paths under the location's url.
CREATE TABLE IF NOT EXISTS `remote_assets` (
	`hash` TEXT NOT NULL,
	`index` INTEGER NOT NULL,
	`chart_path` TEXT NOT NULL,
	`audio_path` TEXT NOT NULL,
	`audio_preview_path` TEXT NOT NULL,
	`background_path` TEXT,
	PRIMARY KEY (`hash`, `index`)
);
