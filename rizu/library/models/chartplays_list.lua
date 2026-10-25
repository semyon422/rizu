local chartplays_list_base = require("sea.storage.server.models.chartplays_list")
local QueryFragments = require("rizu.library.sql.QueryFragments")
local Subtimings = require("sea.chart.Subtimings")

-- The chart's own timings are scored without subtimings, which osu!mania (2100..2200, see Timings.decode) takes as score V1.
local auto_subtimings = ("CASE WHEN chartmetas.timings BETWEEN 2100 AND 2200 THEN %d ELSE 0 END")
	:format(Subtimings("scorev", 1):encode())

---@type rdb.ModelOptions
local chartplays_list = {}

chartplays_list.subquery = [[
SELECT
chartplays.id AS chartplay_id,
chartplays.*,
chartmetas.id AS chartmeta_id,
chartdiffs.id AS chartdiff_id,
chartdiffs.enps_diff AS difficulty,
chartmetas.timings AS auto_timings,
chartplay_accuracies.accuracy AS auto_accuracy,
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
LEFT JOIN chartplay_accuracies ON
chartplay_accuracies.chartplay_id = chartplays.id AND
chartplay_accuracies.timings = chartmetas.timings AND
chartplay_accuracies.subtimings = ]] .. auto_subtimings .. "\n"

chartplays_list.types = chartplays_list_base.types
chartplays_list.relations = chartplays_list_base.relations
chartplays_list.metatable = chartplays_list_base.metatable

return chartplays_list
