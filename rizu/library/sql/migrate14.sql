-- MinaCalc is gone, and so are the values it computed.
DROP INDEX IF EXISTS chartdiffs_msd_idx;
ALTER TABLE chartdiffs DROP COLUMN msd_diff;
ALTER TABLE chartdiffs DROP COLUMN msd_diff_data;
ALTER TABLE chartdiffs DROP COLUMN msd_diff_rates;
ALTER TABLE chartplays DROP COLUMN rating_msd;
