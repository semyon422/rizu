local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local Healths = require("sea.chart.Healths")

---@class sphere.PlayConfig: sea.ReplayBase
local play = {
	modifiers = {},
	rate = 1,
	mode = "mania",

	nearest = false,
	tap_only = false,
	timings = Timings("sphere"),
	subtimings = nil,
	healths = Healths("simple", 20),
	columns_order = nil,

	custom = false,
	const = false,
	rate_type = "linear",

	timing_values = assert(TimingValuesFactory:get(Timings("sphere"))),
}

return play
