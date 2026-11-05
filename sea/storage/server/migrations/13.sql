-- MinaCalc is gone: leaderboards that rated by it (rating_calc 4) fall back to enps (2).
UPDATE OR ROLLBACK leaderboards SET rating_calc = 2 WHERE rating_calc = 4;

DROP INDEX IF EXISTS chartdiffs_msd_idx;
ALTER TABLE chartdiffs DROP COLUMN msd_diff;
ALTER TABLE chartdiffs DROP COLUMN msd_diff_data;
ALTER TABLE chartdiffs DROP COLUMN msd_diff_rates;
ALTER TABLE chartplays DROP COLUMN rating_msd;
