CREATE UNIQUE INDEX IF NOT EXISTS chartplays_replay_hash_idx
ON chartplays (`replay_hash`);

CREATE TABLE IF NOT EXISTS `compute_jobs` (
	`id` INTEGER PRIMARY KEY,
	`chartplay_id` INTEGER NOT NULL,
	`idempotency_key` TEXT NOT NULL,
	`state` INTEGER NOT NULL,
	`attempt_count` INTEGER NOT NULL,
	`max_attempts` INTEGER NOT NULL,
	`created_at` INTEGER NOT NULL,
	`updated_at` INTEGER NOT NULL,
	`next_attempt_at` INTEGER NOT NULL,
	`lease_owner` TEXT,
	`lease_expires_at` INTEGER,
	`compute_version` TEXT NOT NULL,
	`chartdiff` TEXT NOT NULL,
	`last_error_kind` TEXT,
	`last_error_code` TEXT,
	`last_error_message` TEXT,
	`replay_load_time` REAL,
	`chart_parse_time` REAL,
	`difficulty_time` REAL,
	`replay_time` REAL,
	FOREIGN KEY (`chartplay_id`) REFERENCES chartplays(`id`) ON DELETE CASCADE,
	UNIQUE (`chartplay_id`),
	UNIQUE (`idempotency_key`)
);

CREATE INDEX IF NOT EXISTS compute_jobs_claim_idx
ON compute_jobs (`state`, `next_attempt_at`, `lease_expires_at`, `created_at`);
