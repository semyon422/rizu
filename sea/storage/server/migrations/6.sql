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
