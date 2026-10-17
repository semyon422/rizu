local table_util = require("table_util")
local chartplays = require("sea.storage.server.models.chartplays")

---@type rdb.ModelOptions
local best_chartmeta_chartplays = table_util.copy(chartplays)

best_chartmeta_chartplays.subquery = [[
SELECT
	chartplays.id AS chartplay_id,
	chartplays.*,
	MAX(chartplays.rating) AS rating,
	users.name AS user_name,
	users.avatar AS user_avatar,
	chartdiffs.enps_diff AS difficulty,
	chartdiffs.inputmode
FROM chartplays
LEFT JOIN users ON
	chartplays.user_id = users.id
LEFT JOIN chartdiffs ON
	chartplays.hash = chartdiffs.hash AND
	chartplays.`index` = chartdiffs.`index` AND
	chartplays.modifiers = chartdiffs.modifiers AND
	chartplays.rate = chartdiffs.rate AND
	chartplays.mode = chartdiffs.mode
GROUP BY
	users.id,
	chartplays.hash,
	chartplays.`index`
ORDER BY
	rating DESC
]]

return best_chartmeta_chartplays
