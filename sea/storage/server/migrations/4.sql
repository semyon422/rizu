CREATE TABLE IF NOT EXISTS `bancho_credentials` (
	`user_id` INTEGER NOT NULL PRIMARY KEY,
	`password_md5_bcrypt` TEXT NOT NULL,
	`created_at` INTEGER NOT NULL,
	`updated_at` INTEGER NOT NULL
);
