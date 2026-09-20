local table_util = require("table_util")
local chartplays = require("sea.storage.server.models.chartplays")

---@type rdb.ModelOptions
local chartplays_list = table_util.copy(chartplays)

chartplays_list.subquery = [[
SELECT
	chartplays.id AS chartplay_id,
	chartplays.*,
	chartmetas.id AS chartmeta_id,
	chartdiffs.id AS chartdiff_id,
	chartdiffs.enps_diff AS difficulty,
	chartdiffs.inputmode,
	users.name AS user_name,
	users.avatar AS user_avatar
FROM chartplays
LEFT JOIN users ON
	chartplays.user_id = users.id
LEFT JOIN chartdiffs ON
	chartplays.hash = chartdiffs.hash AND
	chartplays.`index` = chartdiffs.`index` AND
	chartplays.modifiers = chartdiffs.modifiers AND
	chartplays.rate = chartdiffs.rate
LEFT JOIN chartmetas ON
	chartplays.hash = chartmetas.hash AND
	chartplays.`index` = chartmetas.`index`
]]

return chartplays_list
