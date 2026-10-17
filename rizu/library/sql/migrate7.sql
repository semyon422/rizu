
CREATE TABLE IF NOT EXISTS `difftables` (
	`id` INTEGER PRIMARY KEY,
	`name` TEXT NOT NULL,
	`description` TEXT NOT NULL,
	`symbol` TEXT NOT NULL,
	`tag` TEXT,
	`created_at` INTEGER NOT NULL,
	UNIQUE(`name`),
	UNIQUE(`tag`)
);

CREATE TABLE IF NOT EXISTS `difftable_chartmetas` (
	`id` INTEGER PRIMARY KEY,
	`user_id` INTEGER NOT NULL,
	`difftable_id` INTEGER NOT NULL,
	`hash` TEXT NOT NULL,
	`index` INTEGER NOT NULL,
	`level` REAL NOT NULL,
	`is_deleted` INTEGER NOT NULL,
	`change_index` INTEGER NOT NULL,
	`created_at` INTEGER NOT NULL,
	`updated_at` INTEGER NOT NULL,
	FOREIGN KEY (difftable_id) REFERENCES difftables(id) ON DELETE CASCADE,
	UNIQUE(`hash`, `index`, `difftable_id`)
);

CREATE INDEX IF NOT EXISTS difftable_chartmetas_difftable_id_idx ON difftable_chartmetas (`difftable_id`);
CREATE INDEX IF NOT EXISTS difftable_chartmetas_hash_index_idx ON difftable_chartmetas (`hash`, `index`);
CREATE INDEX IF NOT EXISTS difftable_chartmetas_is_deleted_idx ON difftable_chartmetas (`is_deleted`);
CREATE UNIQUE INDEX IF NOT EXISTS difftable_chartmetas_change_index_dt_id_idx ON difftable_chartmetas (`difftable_id`, `change_index`);
CREATE INDEX IF NOT EXISTS difftable_chartmetas_change_index_idx ON difftable_chartmetas (`change_index`);
