ALTER TABLE compute_jobs ADD COLUMN chart_upload_size INTEGER NOT NULL DEFAULT 0;
ALTER TABLE compute_jobs ADD COLUMN replay_upload_size INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS `chartplay_effects` (
	`id` INTEGER PRIMARY KEY,
	`chartplay_id` INTEGER NOT NULL,
	`effect` INTEGER NOT NULL,
	`state` INTEGER NOT NULL,
	`attempt_count` INTEGER NOT NULL,
	`max_attempts` INTEGER NOT NULL,
	`created_at` INTEGER NOT NULL,
	`updated_at` INTEGER NOT NULL,
	`next_attempt_at` INTEGER NOT NULL,
	`lease_owner` TEXT,
	`lease_expires_at` INTEGER,
	`chart_upload_size` INTEGER NOT NULL,
	`replay_upload_size` INTEGER NOT NULL,
	`last_error_kind` TEXT,
	`last_error_code` TEXT,
	`last_error_message` TEXT,
	FOREIGN KEY (`chartplay_id`) REFERENCES chartplays(`id`) ON DELETE CASCADE,
	UNIQUE (`chartplay_id`, `effect`)
);

CREATE INDEX IF NOT EXISTS chartplay_effects_claim_idx
ON chartplay_effects (`state`, `next_attempt_at`, `lease_expires_at`, `created_at`);
