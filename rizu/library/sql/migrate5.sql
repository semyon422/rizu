CREATE TABLE IF NOT EXISTS `chartmetas_new` (
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

INSERT INTO chartmetas_new (
`id`,
`created_at`,
`computed_at`,
`osu_ranked_status`,
`hash`,
`index`,
`inputmode`,
`format`,
`timings`,
`healths`,
`title`,
`title_unicode`,
`artist`,
`artist_unicode`,
`name`,
`creator`,
`level`,
`source`,
`tags`,
`audio_path`,
`audio_offset`,
`background_path`,
`preview_time`,
`osu_beatmap_id`,
`osu_beatmapset_id`,
`tempo`,
`tempo_avg`,
`tempo_max`,
`tempo_min`
)
SELECT
`id`,
0,
0,
NULL,
`hash`,
`index`,
`inputmode`,
0,
NULL,
NULL,
`title`,
`title`,
`artist`,
`artist`,
`name`,
`creator`,
`level`,
`source`,
`tags`,
`audio_path`,
`audio_offset`,
`background_path`,
`preview_time`,
`osu_beatmap_id`,
`osu_beatmapset_id`,
`tempo`,
NULL,
NULL,
NULL
FROM chartmetas;

DROP TABLE chartmetas;

ALTER TABLE chartmetas_new RENAME TO chartmetas;

CREATE INDEX IF NOT EXISTS chartmetas_hash_idx ON chartmetas (`hash`);
CREATE UNIQUE INDEX IF NOT EXISTS chartmetas_hash_index_idx ON chartmetas (`hash`, `index`);
CREATE INDEX IF NOT EXISTS chartmetas_inputmode_idx ON chartmetas (`inputmode`);


CREATE TABLE IF NOT EXISTS `chartdiffs_new` (
	`id` INTEGER PRIMARY KEY,
	`custom_user_id` INTEGER,
	`created_at` INTEGER NOT NULL,
	`computed_at` INTEGER NOT NULL,

	`hash` TEXT NOT NULL,
	`index` INTEGER NOT NULL,
	`modifiers` TEXT NOT NULL,
	`rate` INTEGER NOT NULL,
	`mode` INTEGER NOT NULL,

	`inputmode` TEXT,
	`duration` REAL,
	`start_time` REAL,
	`notes_count` INTEGER,
	`judges_count` INTEGER,
	`note_types_count` TEXT,
	`density_data` TEXT,
	`sv_data` TEXT,
	`enps_diff` REAL,
	`osu_diff` REAL,
	`msd_diff` REAL,
	`msd_diff_data` BLOB,
	`msd_diff_rates` BLOB,
	`user_diff` REAL,
	`user_diff_data` BLOB,
	`notes_preview` BLOB
);

INSERT INTO chartdiffs_new (
`id`,
`created_at`,
`computed_at`,
`hash`,
`index`,
`modifiers`,
`rate`,
`mode`,
`inputmode`,
`duration`,
`start_time`,
`notes_count`,
`judges_count`,
`note_types_count`,
`density_data`,
`sv_data`,
`enps_diff`,
`osu_diff`,
`msd_diff`,
`msd_diff_data`,
`msd_diff_rates`,
`user_diff`,
`user_diff_data`,
`notes_preview`
)
SELECT
`id`,
0,
0,
`hash`,
`index`,
`modifiers`,
`rate`,
0,
`inputmode`,
NULL,
NULL,
`notes_count`,
NULL,
NULL,
`density_data`,
`sv_data`,
`enps_diff`,
`osu_diff`,
`msd_diff`,
`msd_diff_data`,
'',
`user_diff`,
`user_diff_data`,
`notes_preview`
FROM chartdiffs;

DROP TABLE chartdiffs;

ALTER TABLE chartdiffs_new RENAME TO chartdiffs;

CREATE INDEX IF NOT EXISTS chartdiffs_hi_idx ON chartdiffs (`hash`, `index`);
CREATE INDEX IF NOT EXISTS chartdiffs_himr_idx ON chartdiffs (`hash`, `index`, `modifiers`, `rate`);
CREATE UNIQUE INDEX IF NOT EXISTS chartdiffs_himrmc_idx ON chartdiffs (`hash`, `index`, `modifiers`, `rate`, `mode`, `custom_user_id`);
CREATE INDEX IF NOT EXISTS chartdiffs_inputmode_idx ON chartdiffs (`inputmode`);
CREATE INDEX IF NOT EXISTS chartdiffs_enps_idx ON chartdiffs (`enps_diff`);
CREATE INDEX IF NOT EXISTS chartdiffs_osu_idx ON chartdiffs (`osu_diff`);
CREATE INDEX IF NOT EXISTS chartdiffs_msd_idx ON chartdiffs (`msd_diff`);
CREATE INDEX IF NOT EXISTS chartdiffs_user_idx ON chartdiffs (`user_diff`);


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

CREATE INDEX IF NOT EXISTS chartplays_himr_idx ON chartplays (`hash`, `index`, `modifiers`, `rate`);
CREATE INDEX IF NOT EXISTS chartplays_himrm_idx ON chartplays (`hash`, `index`, `modifiers`, `rate`, `mode`);

INSERT INTO chartplays (
`id`,
`user_id`,
`compute_state`,
`computed_at`,
`submitted_at`,

`replay_hash`,
`pause_count`,
`created_at`,

`hash`,
`index`,

`modifiers`,
`rate`,
`mode`,

`nearest`,
`tap_only`,

`custom`,
`const`,
`rate_type`,

`judges`,
`accuracy`,
`max_combo`,
`miss_count`,
`not_perfect_count`,
`pass`,
`rating`,
`rating_pp`,
`rating_msd`
)
SELECT
`id`,
1,
'new',
`time`,
`time`,
`replay_hash`,
CASE
    WHEN `pauses` IS NOT NULL THEN `pauses`
    ELSE 0
END,
`time`,

`hash`,
`index`,

`modifiers`,
`rate`,
CASE
    WHEN `single` IS NOT NULL THEN `single`
    ELSE 0
END,

0,
0,

0,
`const`,
`rate_type`,

'',
`accuracy`,
`max_combo`,
`miss`,
CASE
    WHEN `not_perfect` IS NOT NULL THEN `not_perfect`
    ELSE 0
END,
1,
0,
0,
0
FROM scores;

DROP INDEX scores_himr_idx;
DROP TABLE scores;

CREATE INDEX IF NOT EXISTS chartplays_user_id_idx ON chartplays (`user_id`);
CREATE INDEX IF NOT EXISTS chartplays_himr_idx ON chartplays (`hash`, `index`, `modifiers`, `rate`);
CREATE INDEX IF NOT EXISTS chartplays_himrm_idx ON chartplays (`hash`, `index`, `modifiers`, `rate`, `mode`);
