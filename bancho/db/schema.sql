-- Bancho database schema.
-- Version 2: added session fields to users table.

-- User accounts.
CREATE TABLE IF NOT EXISTS `users` (
	`id` INTEGER PRIMARY KEY AUTOINCREMENT,
	`name` TEXT NOT NULL,
	`email` TEXT NOT NULL,
	`pw_bcrypt` TEXT NOT NULL,
	`priv` INTEGER NOT NULL DEFAULT 0,
	`country_acronym` TEXT NOT NULL DEFAULT '',
	`country_code` TEXT NOT NULL DEFAULT '',
	`silence_end` INTEGER NOT NULL DEFAULT 0,
	`token` TEXT NOT NULL DEFAULT '',
	`path_md5` TEXT NOT NULL DEFAULT '',
	`adapters_md5` TEXT NOT NULL DEFAULT '',
	`uninstall_md5` TEXT NOT NULL DEFAULT '',
	`disk_signature_md5` TEXT NOT NULL DEFAULT '',
	`is_restricted` INTEGER NOT NULL DEFAULT 0,
	`is_bot` INTEGER NOT NULL DEFAULT 0,
	`created_at` INTEGER NOT NULL DEFAULT 0,
	-- Session preferences (persisted from Player)
	`utc_offset` INTEGER NOT NULL DEFAULT 0,
	`pm_private` INTEGER NOT NULL DEFAULT 0,
	`stealth` INTEGER NOT NULL DEFAULT 0,
	`away_msg` TEXT NOT NULL DEFAULT '',
	`pres_filter` INTEGER NOT NULL DEFAULT 0,
	UNIQUE(`name`),
	UNIQUE(`email`)
);

CREATE INDEX IF NOT EXISTS users_token_idx ON `users` (`token`);

-- Per-mode player stats.
CREATE TABLE IF NOT EXISTS `stats` (
	`user_id` INTEGER NOT NULL,
	`mode` INTEGER NOT NULL,
	`tscore` INTEGER NOT NULL DEFAULT 0,
	`rscore` INTEGER NOT NULL DEFAULT 0,
	`pp` REAL NOT NULL DEFAULT 0,
	`acc` REAL NOT NULL DEFAULT 0,
	`plays` INTEGER NOT NULL DEFAULT 0,
	`playtime` REAL NOT NULL DEFAULT 0,
	`max_combo` INTEGER NOT NULL DEFAULT 0,
	`rank` INTEGER NOT NULL DEFAULT 0,
	`country_rank` INTEGER NOT NULL DEFAULT 0,
	`total_hits` INTEGER NOT NULL DEFAULT 0,
	`xh_count` INTEGER NOT NULL DEFAULT 0,
	`x_count` INTEGER NOT NULL DEFAULT 0,
	`sh_count` INTEGER NOT NULL DEFAULT 0,
	`s_count` INTEGER NOT NULL DEFAULT 0,
	`a_count` INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY (`user_id`, `mode`)
);

CREATE INDEX IF NOT EXISTS stats_pp_idx ON `stats` (`pp` DESC);

-- Beatmap metadata.
CREATE TABLE IF NOT EXISTS `beatmaps` (
	`id` INTEGER NOT NULL PRIMARY KEY,
	`set_id` INTEGER NOT NULL,
	`md5` TEXT NOT NULL,
	`artist` TEXT NOT NULL,
	`title` TEXT NOT NULL,
	`version` TEXT NOT NULL,
	`creator` TEXT NOT NULL,
	`total_length` INTEGER NOT NULL DEFAULT 0,
	`max_combo` INTEGER NOT NULL DEFAULT 0,
	`status` INTEGER NOT NULL DEFAULT 0,
	`mode` INTEGER NOT NULL DEFAULT 0,
	`bpm` REAL NOT NULL DEFAULT 0,
	`cs` REAL NOT NULL DEFAULT 0,
	`od` REAL NOT NULL DEFAULT 0,
	`ar` REAL NOT NULL DEFAULT 0,
	`hp` REAL NOT NULL DEFAULT 0,
	`diff` REAL NOT NULL DEFAULT 0,
	`plays` INTEGER NOT NULL DEFAULT 0,
	`passes` INTEGER NOT NULL DEFAULT 0,
	`last_update` INTEGER NOT NULL DEFAULT 0,
	UNIQUE(`md5`)
);

CREATE INDEX IF NOT EXISTS beatmaps_id_idx ON `beatmaps` (`id`);
CREATE INDEX IF NOT EXISTS beatmaps_set_id_idx ON `beatmaps` (`set_id`);

-- Score records.
CREATE TABLE IF NOT EXISTS `scores` (
	`id` INTEGER PRIMARY KEY AUTOINCREMENT,
	`map_md5` TEXT NOT NULL,
	`score` INTEGER NOT NULL,
	`pp` REAL NOT NULL DEFAULT 0,
	`acc` REAL NOT NULL DEFAULT 0,
	`max_combo` INTEGER NOT NULL DEFAULT 0,
	`mods` INTEGER NOT NULL DEFAULT 0,
	`n300` INTEGER NOT NULL DEFAULT 0,
	`n100` INTEGER NOT NULL DEFAULT 0,
	`n50` INTEGER NOT NULL DEFAULT 0,
	`nmiss` INTEGER NOT NULL DEFAULT 0,
	`ngeki` INTEGER NOT NULL DEFAULT 0,
	`nkatu` INTEGER NOT NULL DEFAULT 0,
	`grade` INTEGER NOT NULL DEFAULT 0,
	`status` INTEGER NOT NULL DEFAULT 0,
	`mode` INTEGER NOT NULL DEFAULT 0,
	`play_time` INTEGER NOT NULL DEFAULT 0,
	`time_elapsed` REAL NOT NULL DEFAULT 0,
	`client_flags` INTEGER NOT NULL DEFAULT 0,
	`user_id` INTEGER NOT NULL,
	`perfect` INTEGER NOT NULL DEFAULT 0,
	`online_checksum` TEXT NOT NULL DEFAULT '',
	`created_at` INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS scores_map_md5_idx ON `scores` (`map_md5`);
CREATE INDEX IF NOT EXISTS scores_user_id_idx ON `scores` (`user_id`);
CREATE INDEX IF NOT EXISTS scores_pp_idx ON `scores` (`pp` DESC);

-- Friendship relations.
CREATE TABLE IF NOT EXISTS `friends` (
	`user_id` INTEGER NOT NULL,
	`friend_id` INTEGER NOT NULL,
	PRIMARY KEY (`user_id`, `friend_id`)
);

CREATE INDEX IF NOT EXISTS friends_friend_id_idx ON `friends` (`friend_id`);

-- Favourited beatmap sets.
CREATE TABLE IF NOT EXISTS `favourites` (
	`user_id` INTEGER NOT NULL,
	`set_id` INTEGER NOT NULL,
	PRIMARY KEY (`user_id`, `set_id`)
);

CREATE INDEX IF NOT EXISTS favourites_set_id_idx ON `favourites` (`set_id`);

-- Replay file data (stored as BLOB).
CREATE TABLE IF NOT EXISTS `replays` (
	`score_id` INTEGER NOT NULL PRIMARY KEY,
	`data` BLOB NOT NULL
);
