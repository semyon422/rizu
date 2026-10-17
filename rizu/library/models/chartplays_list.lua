local chartplays_list_base = require("sea.storage.server.models.chartplays_list")
local QueryFragments = require("rizu.library.sql.QueryFragments")

---@type rdb.ModelOptions
local chartplays_list = {}

chartplays_list.subquery = [[
SELECT
chartplays.id AS chartplay_id,
chartplays.*,
chartmetas.id AS chartmeta_id,
chartdiffs.id AS chartdiff_id,
chartdiffs.enps_diff AS difficulty,
]]
	.. QueryFragments.FIELDS_CHARTDIFF .. ", "
	.. QueryFragments.FIELDS_CHARTDIFF_PREVIEW .. [[
FROM chartplays
LEFT JOIN chartdiffs ON
chartplays.hash = chartdiffs.hash AND
chartplays.`index` = chartdiffs.`index` AND
chartplays.modifiers = chartdiffs.modifiers AND
chartplays.rate = chartdiffs.rate
LEFT JOIN chartmetas ON
chartplays.hash = chartmetas.hash AND
chartplays.`index` = chartmetas.`index`
]]

chartplays_list.types = chartplays_list_base.types
chartplays_list.relations = chartplays_list_base.relations
chartplays_list.metatable = chartplays_list_base.metatable

return chartplays_list
