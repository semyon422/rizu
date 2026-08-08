
CREATE TABLE IF NOT EXISTS `chartmetas` (
	`id` INTEGER PRIMARY KEY,
	`created_at` INTEGER NOT NULL,
	`computed_at` INTEGER NOT NULL,
	`osu_ranked_status` INTEGER,

	`hash` TEXT NOT NULL,
	`index` INTEGER NOT NULL,

	`inputmode` TEXT NOT NULL,
	`format` INTEGER NOT NULL,
	`timings` INTEGER,
	`healths` INTEGER,
	`title` TEXT,
	`title_unicode` TEXT,
	`artist` TEXT,
	`artist_unicode` TEXT,
	`name` TEXT,
	`creator` TEXT,
	`level` REAL,
	`source` TEXT,
	`tags` TEXT,
	`audio_path` TEXT,
	`audio_offset` REAL,
	`background_path` TEXT,
	`preview_time` REAL,
	`osu_beatmap_id` INTEGER,
	`osu_beatmapset_id` INTEGER,
	`tempo` REAL,
	`tempo_avg` REAL,
	`tempo_max` REAL,
	`tempo_min` REAL
);

CREATE INDEX IF NOT EXISTS chartmetas_hash_idx ON chartmetas (`hash`);
CREATE UNIQUE INDEX IF NOT EXISTS chartmetas_hash_index_idx ON chartmetas (`hash`, `index`);
CREATE INDEX IF NOT EXISTS chartmetas_inputmode_idx ON chartmetas (`inputmode`);
CREATE INDEX IF NOT EXISTS chartmetas_title_idx ON chartmetas (`title`);
CREATE INDEX IF NOT EXISTS chartmetas_artist_idx ON chartmetas (`artist`);
CREATE INDEX IF NOT EXISTS chartmetas_level_idx ON chartmetas (`level`);

CREATE TABLE IF NOT EXISTS `chartdiffs` (
	`id` INTEGER PRIMARY KEY,
	`custom_user_id` INTEGER,
	`created_at` INTEGER NOT NULL,
	`computed_at` INTEGER NOT NULL,

	`hash` TEXT NOT NULL,
	`index` INTEGER NOT NULL,
	`modifiers` TEXT NOT NULL,
	`rate` INTEGER NOT NULL,
	`mode` INTEGER NOT NULL,

	`inputmode` TEXT NOT NULL,
	`duration` REAL NOT NULL,
	`start_time` REAL NOT NULL,
	`notes_count` INTEGER NOT NULL,
	`judges_count` INTEGER NOT NULL,
	`note_types_count` TEXT NOT NULL,
	`density_data` TEXT NOT NULL,
	`sv_data` TEXT NOT NULL,
	`enps_diff` REAL NOT NULL,
	`osu_diff` REAL NOT NULL,
	`msd_diff` REAL NOT NULL,
	`msd_diff_data` BLOB NOT NULL,
	`msd_diff_rates` BLOB NOT NULL,
	`user_diff` REAL NOT NULL,
	`user_diff_data` BLOB NOT NULL,
	`notes_preview` BLOB NOT NULL
);

CREATE INDEX IF NOT EXISTS chartdiffs_hi_idx ON chartdiffs (`hash`, `index`);
CREATE INDEX IF NOT EXISTS chartdiffs_himr_idx ON chartdiffs (`hash`, `index`, `modifiers`, `rate`);
CREATE UNIQUE INDEX IF NOT EXISTS chartdiffs_himrmc_idx ON chartdiffs (`hash`, `index`, `modifiers`, `rate`, `mode`, `custom_user_id`);
CREATE INDEX IF NOT EXISTS chartdiffs_inputmode_idx ON chartdiffs (`inputmode`);
CREATE INDEX IF NOT EXISTS chartdiffs_enps_idx ON chartdiffs (`enps_diff`);
CREATE INDEX IF NOT EXISTS chartdiffs_osu_idx ON chartdiffs (`osu_diff`);
CREATE INDEX IF NOT EXISTS chartdiffs_msd_idx ON chartdiffs (`msd_diff`);
CREATE INDEX IF NOT EXISTS chartdiffs_user_idx ON chartdiffs (`user_diff`);
CREATE INDEX IF NOT EXISTS chartdiffs_notes_count_idx ON chartdiffs (`notes_count`);
CREATE INDEX IF NOT EXISTS chartdiffs_duration_idx ON chartdiffs (`duration`);

CREATE TABLE IF NOT EXISTS `chartplays` (
	`id` INTEGER PRIMARY KEY,
	`user_id` INTEGER NOT NULL,
	`compute_state` INTEGER NOT NULL,
	`computed_at` INTEGER NOT NULL,
	`submitted_at` INTEGER NOT NULL,

	`replay_hash` TEXT NOT NULL,
	`pause_count` INTEGER NOT NULL,
	`created_at` INTEGER NOT NULL,

	`hash` TEXT NOT NULL,
	`index` INTEGER NOT NULL,

	`modifiers` TEXT NOT NULL,
	`rate` INTEGER NOT NULL,
	`mode` INTEGER NOT NULL,

	`nearest` INTEGER NOT NULL,
	`tap_only` INTEGER NOT NULL,
	`timings` INTEGER,
	`subtimings` INTEGER,
	`healths` INTEGER,
	`columns_order` BLOB,

	`custom` INTEGER NOT NULL,
	`const` INTEGER NOT NULL,
	`rate_type` INTEGER NOT NULL,

	`judges` BLOB NOT NULL,
	`accuracy` REAL NOT NULL,
	`max_combo` INTEGER NOT NULL,
	`miss_count` INTEGER NOT NULL,
	`not_perfect_count` INTEGER NOT NULL,
	`pass` INTEGER NOT NULL,
	`rating` REAL NOT NULL,
	`rating_pp` REAL NOT NULL,
	`rating_msd` REAL NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS chartplays_replay_hash_idx ON chartplays (`replay_hash`);
CREATE INDEX IF NOT EXISTS chartplays_user_id_idx ON chartplays (`user_id`);
CREATE INDEX IF NOT EXISTS chartplays_himr_idx ON chartplays (`hash`, `index`, `modifiers`, `rate`);
CREATE INDEX IF NOT EXISTS chartplays_himrm_idx ON chartplays (`hash`, `index`, `modifiers`, `rate`, `mode`);
CREATE INDEX IF NOT EXISTS chartplays_himrm_stat_idx ON chartplays (`hash`, `index`, `modifiers`, `rate`, `mode`, `accuracy`, `miss_count`, `created_at`);

CREATE TABLE IF NOT EXISTS `user_activity_days` (
	`id` INTEGER PRIMARY KEY,
	`user_id` INTEGER NOT NULL,
	`timezone` INTEGER NOT NULL,
	`year` INTEGER NOT NULL,
	`month` INTEGER NOT NULL,
	`day` INTEGER NOT NULL,
	`count` INTEGER NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS user_activity_days_full_idx ON user_activity_days (`user_id`, `timezone`, `year`, `month`, `day`);

CREATE TABLE IF NOT EXISTS `difftables` (
	`id` INTEGER PRIMARY KEY,
	`name` TEXT NOT NULL,
	`description` TEXT NOT NULL,
	`symbol` TEXT NOT NULL,
	`tag` TEXT,
	`created_at` INTEGER NOT NULL,
	UNIQUE(`name`)
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
