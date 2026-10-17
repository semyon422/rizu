
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
