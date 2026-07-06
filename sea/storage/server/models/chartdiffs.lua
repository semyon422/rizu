local int_rates = require("chart.scoring.int_rates")
local stbl = require("stbl")
local Gamemode = require("sea.chart.Gamemode")
local Chartdiff = require("sea.chart.Chartdiff")
local Modifiers = require("sea.storage.server.Modifiers")
local MsdDiffData = require("chart.difficulty.MsdDiffData")
local MsdDiffRates = require("chart.difficulty.MsdDiffRates")

---@type rdb.ModelOptions
local chartdiffs = {}

chartdiffs.metatable = Chartdiff

chartdiffs.types = {
	modifiers = Modifiers,
	rate = int_rates,
	mode = Gamemode,
	note_types_count = stbl,
	density_data = stbl,
	sv_data = stbl,
	msd_diff_data = MsdDiffData,
	msd_diff_rates = MsdDiffRates,
}

return chartdiffs
