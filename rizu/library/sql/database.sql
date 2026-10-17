CREATE TABLE IF NOT EXISTS `chartfiles` (
	`id` INTEGER PRIMARY KEY,
	`name` TEXT NOT NULL,
	`hash` TEXT,
	`set_id` INTEGER NOT NULL,
	`modified_at` INTEGER NOT NULL,
	`size` INTEGER,
	FOREIGN KEY (set_id) REFERENCES chartfile_sets(id) ON DELETE CASCADE,
	UNIQUE(`set_id`, `name`)
);

CREATE INDEX IF NOT EXISTS chartfiles_hash_idx ON chartfiles (`hash`);
CREATE INDEX IF NOT EXISTS chartfiles_modified_at_idx ON chartfiles (`modified_at`);

CREATE TABLE IF NOT EXISTS `chartfile_sets` (
	`id` INTEGER PRIMARY KEY,
	`dir` TEXT,
	`name` TEXT NOT NULL,
	`modified_at` INTEGER NOT NULL,
	`is_file` INTEGER NOT NULL,
	`location_id` INTEGER NOT NULL,
	FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE,
	UNIQUE(`location_id`, `dir`, `name`)
);

CREATE INDEX IF NOT EXISTS chartfile_sets_modified_at_idx ON chartfile_sets (`modified_at`);

CREATE TABLE IF NOT EXISTS `locations` (
	`id` INTEGER PRIMARY KEY,
	`path` TEXT UNIQUE,
	`name` TEXT NOT NULL,
	`is_relative` INTEGER NOT NULL,
	`is_internal` INTEGER NOT NULL,
	`url` TEXT
);

CREATE TABLE IF NOT EXISTS `remote_assets` (
	`hash` TEXT NOT NULL,
	`index` INTEGER NOT NULL,
	`chart_path` TEXT NOT NULL,
	`audio_path` TEXT NOT NULL,
	`audio_preview_path` TEXT NOT NULL,
	`background_path` TEXT,
	PRIMARY KEY (`hash`, `index`)
);

CREATE TABLE IF NOT EXISTS `collections` (
	`id` INTEGER PRIMARY KEY,
	`name` TEXT
);

CREATE TABLE IF NOT EXISTS `chart_collections` (
	`id` INTEGER PRIMARY KEY,
	`collection_id` INTEGER,
	`chartdiff_id` INTEGER
);

CREATE TABLE IF NOT EXISTS `chartmeta_user_datas` (
	`id` INTEGER PRIMARY KEY,

	`hash` TEXT NOT NULL,
	`index` INTEGER NOT NULL,
	`user_id` INTEGER NOT NULL,

	`local_offset` REAL,
	`rating` REAL,
	`comment` TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS chartmeta_user_datas_hi_idx ON chartmeta_user_datas (`hash`, `index`);
CREATE UNIQUE INDEX IF NOT EXISTS chartmeta_user_datas_hiu_idx ON chartmeta_user_datas (`hash`, `index`, `user_id`);
