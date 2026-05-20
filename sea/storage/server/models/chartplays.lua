local Gamemode = require("sea.chart.Gamemode")
local Chartplay = require("sea.chart.Chartplay")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local Healths = require("sea.chart.Healths")
local RateType = require("sea.chart.RateType")
local int_rates = require("chart.scoring.int_rates")
local IntegerArray = require("sea.storage.server.IntegerArray")
local IntegerArrayOptional = require("sea.storage.server.IntegerArrayOptional")
local Modifiers = require("sea.storage.server.Modifiers")

---@type rdb.ModelOptions
local chartplays = {}

chartplays.metatable = Chartplay

chartplays.types = {
	nearest = "boolean",
	pass = "boolean",
	mode = Gamemode,
	custom = "boolean",
	columns_order = IntegerArrayOptional,
	modifiers = Modifiers,
	judges = IntegerArray,
	tap_only = "boolean",
	const = "boolean",
	rate = int_rates,
	timings = Timings,
	subtimings = Subtimings,
	healths = Healths,
	rate_type = RateType,
}

return chartplays
