CREATE TABLE IF NOT EXISTS `osu_beatmaps_new` (
	`id` INTEGER,
	`beatmapset_id` INTEGER,
	`status` INTEGER NOT NULL,
	`hash` TEXT NOT NULL,
	`updated_at` INTEGER NOT NULL
);

INSERT INTO `osu_beatmaps_new` (`id`, `beatmapset_id`, `status`, `hash`, `updated_at`)
SELECT `id`, `beatmapset_id`, `status`, `hash`, `updated_at`
FROM `osu_beatmaps`;

DROP TABLE `osu_beatmaps`;
ALTER TABLE `osu_beatmaps_new` RENAME TO `osu_beatmaps`;
