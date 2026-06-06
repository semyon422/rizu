CREATE TABLE IF NOT EXISTS `users` (
	`id` INTEGER PRIMARY KEY,
	`name` TEXT NOT NULL,
	`email` TEXT NOT NULL,
	`password` TEXT NOT NULL,
	`description` TEXT NOT NULL,
	`latest_activity` INTEGER NOT NULL,
	`activity_timezone` INTEGER NOT NULL,
	`created_at` INTEGER NOT NULL,
	`is_banned` INTEGER NOT NULL,
	`is_restricted_info` INTEGER NOT NULL,
	`chartplays_count` INTEGER NOT NULL,
	`chartmetas_count` INTEGER NOT NULL,
	`chartdiffs_count` INTEGER NOT NULL,
	`chartfiles_upload_size` INTEGER NOT NULL,
	`chartplays_upload_size` INTEGER NOT NULL,
	`play_time` REAL NOT NULL,
	`enable_gradient` INTEGER NOT NULL,
	`color_left` INTEGER NOT NULL,
	`color_right` INTEGER NOT NULL,
	`avatar` TEXT NOT NULL,
	`banner` TEXT NOT NULL,
	`discord` TEXT NOT NULL,
	`country_code` TEXT NOT NULL,
	`custom_link` TEXT NOT NULL,
	UNIQUE(`name`),
	UNIQUE(`email`)
);

CREATE TABLE IF NOT EXISTS `user_roles` (
	`id` INTEGER PRIMARY KEY,
	`user_id` INTEGER NOT NULL,
	`role` INTEGER NOT NULL,
	`started_at` INTEGER NOT NULL,
	`expires_at` INTEGER,
	`total_time` INTEGER NOT NULL,
	UNIQUE(`user_id`, `role`)
);

CREATE TABLE IF NOT EXISTS `bancho_credentials` (
	`user_id` INTEGER NOT NULL PRIMARY KEY,
	`password_md5_bcrypt` TEXT NOT NULL,
	`created_at` INTEGER NOT NULL,
	`updated_at` INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS `bancho_user_settings` (
	`user_id` INTEGER NOT NULL PRIMARY KEY,
	`utc_offset` INTEGER NOT NULL DEFAULT 0,
	`pm_private` INTEGER NOT NULL DEFAULT 0,
	`stealth` INTEGER NOT NULL DEFAULT 0,
	`away_msg` TEXT NOT NULL DEFAULT '',
	`pres_filter` INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS `user_friends` (
	`user_id` INTEGER NOT NULL,
	`friend_id` INTEGER NOT NULL,
	PRIMARY KEY (`user_id`, `friend_id`)
);

CREATE TABLE IF NOT EXISTS `user_osu_favourites` (
	`user_id` INTEGER NOT NULL,
	`set_id` INTEGER NOT NULL,
	PRIMARY KEY (`user_id`, `set_id`)
);

CREATE TABLE IF NOT EXISTS `user_locations` (
	`id` INTEGER PRIMARY KEY,
	`user_id` INTEGER NOT NULL,
	`ip` TEXT NOT NULL,
	`created_at` INTEGER NOT NULL,
	`updated_at` INTEGER NOT NULL,
	`is_register` INTEGER NOT NULL,
	`sessions_count` INTEGER NOT NULL,
	UNIQUE(`user_id`, `ip`)
);

CREATE TABLE IF NOT EXISTS `user_badges` (
	`user_id` INTEGER NOT NULL,
	`badge` INTEGER NOT NULL,
	UNIQUE (user_id, badge)
);

CREATE TABLE IF NOT EXISTS `sessions` (
	`id` INTEGER PRIMARY KEY,
	`user_id` INTEGER NOT NULL,
	`active` INTEGER NOT NULL,
	`ip` INTEGER NOT NULL,
	`created_at` INTEGER NOT NULL,
	`updated_at` INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS `auth_codes` (
	`id` INTEGER PRIMARY KEY,
	`user_id` INTEGER,
	`type` INTEGER NOT NULL,
	`created_at` INTEGER NOT NULL,
	`expires_at` INTEGER NOT NULL,
	`used` INTEGER NOT NULL,
	`ip` TEXT NOT NULL,
	`code` TEXT NOT NULL,
	UNIQUE(`code`)
);

CREATE TABLE IF NOT EXISTS `chartfiles` (
	`id` INTEGER PRIMARY KEY,
	`hash` TEXT NOT NULL,
	`name` TEXT NOT NULL,
	`size` INTEGER NOT NULL,
	`compute_state` INTEGER NOT NULL,
	`computed_at` INTEGER NOT NULL,
	`creator_id` INTEGER NOT NULL,
	`submitted_at` INTEGER NOT NULL,
	UNIQUE(`hash`)
);

CREATE TABLE IF NOT EXISTS `compute_tasks` (
	`id` INTEGER PRIMARY KEY,
	`created_at` INTEGER NOT NULL,
	`completed_at` INTEGER,
	`state` INTEGER NOT NULL,
	`target` INTEGER NOT NULL,
	`current` INTEGER NOT NULL,
	`total` INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS `leaderboards` (
	`id` INTEGER PRIMARY KEY,
	`name` TEXT,
	`description` TEXT,
	`created_at` INTEGER,
	`rating_calc` INTEGER,
	`nearest` INTEGER,
	`pass` INTEGER,
	`judges` INTEGER,
	`allow_custom` INTEGER,
	`allow_const` INTEGER,
	`allow_pause` INTEGER,
	`allow_reorder` INTEGER,
	`allow_modifiers` INTEGER,
	`allow_tap_only` INTEGER,
	`allow_free_timings` INTEGER,
	`allow_free_healths` INTEGER,
	`timings` INTEGER,
	`healths` INTEGER,
	`starts_at` INTEGER,
	`ends_at` INTEGER,
	`mode` INTEGER,
	`rate` BLOB,
	`difftables` BLOB,
	`chartmeta_inputmode` BLOB,
	`chartdiff_inputmode` BLOB,
	UNIQUE(`name`)
);

CREATE TABLE IF NOT EXISTS `leaderboard_users` (
	`id` INTEGER PRIMARY KEY,
	`leaderboard_id` INTEGER NOT NULL,
	`user_id` INTEGER NOT NULL,
	`total_rating` REAL NOT NULL,
	`total_accuracy` REAL NOT NULL,
	`total_plays` INTEGER NOT NULL,
	`ranked_plays` INTEGER NOT NULL,
	`rank` INTEGER NOT NULL,
	`updated_at` INTEGER NOT NULL,
	UNIQUE(`leaderboard_id`, `user_id`)
);

CREATE INDEX IF NOT EXISTS leaderboard_users_total_rating_idx ON leaderboard_users (`total_rating`);

CREATE TABLE IF NOT EXISTS `leaderboard_difftables` (
	`id` INTEGER PRIMARY KEY,
	`leaderboard_id` INTEGER NOT NULL,
	`difftable_id` INTEGER NOT NULL,
	UNIQUE(`leaderboard_id`, `difftable_id`)
);

CREATE TABLE IF NOT EXISTS `teams` (
	`id` INTEGER PRIMARY KEY,
	`name` TEXT NOT NULL,
	`alias` TEXT NOT NULL,
	`description` TEXT NOT NULL,
	`owner_id` INTEGER NOT NULL,
	`type` INTEGER NOT NULL,
	`users_count` INTEGER NOT NULL,
	`created_at` INTEGER NOT NULL,
	UNIQUE(`name`),
	UNIQUE(`alias`)
);

CREATE TABLE IF NOT EXISTS `team_users` (
	`id` INTEGER PRIMARY KEY,
	`team_id` INTEGER NOT NULL,
	`user_id` INTEGER NOT NULL,
	`is_accepted` INTEGER NOT NULL,
	`is_invitation` INTEGER NOT NULL,
	`created_at` INTEGER NOT NULL,
	UNIQUE(`team_id`, `user_id`)
);

CREATE TABLE IF NOT EXISTS `dan_clears` (
	`id` INTEGER PRIMARY KEY,
	`dan_id` INTEGER NOT NULL,
	`user_id` INTEGER NOT NULL,
	`time` INTEGER NOT NULL,
	`rate` INTEGER NOT NULL,
	`chartplay_ids` TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS `osu_beatmapsets` (
	`id` INTEGER NOT NULL,
	`status` INTEGER NOT NULL,
	`updated_at` INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS `osu_beatmaps` (
	`id` INTEGER NOT NULL,
	`beatmapset_id` INTEGER NOT NULL,
	`status` INTEGER NOT NULL,
	`hash` TEXT NOT NULL,
	`updated_at` INTEGER NOT NULL
);
