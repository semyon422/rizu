local int_rates = require("chart.scoring.int_rates")
local Pattern = require("chart.scoring.Pattern")
local Skillset = require("chart.scoring.Skillset")
local stbl = require("stbl")
local Gamemode = require("sea.chart.Gamemode")
local Chartdiff = require("sea.chart.Chartdiff")
local Modifiers = require("sea.storage.server.Modifiers")

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
	skillset = Skillset,
	pattern_1 = Pattern,
	pattern_2 = Pattern,
}

return chartdiffs
