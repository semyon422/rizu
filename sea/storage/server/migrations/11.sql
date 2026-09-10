-- Preserve existing Gamemode IDs: mania=0, taiko=1, osu=2, catch=3, sdvx=4.
ALTER TABLE chartmetas ADD COLUMN mode INTEGER;
UPDATE chartmetas SET mode = CASE
	WHEN format = 7 THEN 4
	WHEN format = 1 AND inputmode = '1osu' THEN 2
	WHEN format = 1 AND inputmode = '1fruits' THEN 3
	WHEN format = 1 AND inputmode = '1taiko' THEN 1
	WHEN format = 1 AND inputmode = '2key' THEN NULL
	ELSE 0
END;
CREATE INDEX chartmetas_mode_idx ON chartmetas (mode);
