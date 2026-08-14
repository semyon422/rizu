local class = require("class")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local Settings = require("rizu.config.Settings")

---@class rizu.GameplayTimings
---@operator call: rizu.GameplayTimings
local GameplayTimings = class()

local format_timings = {
	sphere = {"sphere"},
	osu = {"osuod"},
	o2jam = {"sphere"},
	bms = {"bmsrank"},
	stepmania = {"etternaj"},
	quaver = {"quaver"},
	midi = {"sphere"},
	ksm = {"sphere"},
	iidx = {"sphere"},
}

---@param settings rizu.config.Config
---@param chartmeta sea.Chartmeta
function GameplayTimings:new(settings, chartmeta)
	self.settings = settings
	self.chartmeta = chartmeta
end

---@param replayBase sea.ReplayBase
function GameplayTimings:apply(replayBase)
	local settings = self.settings
	local chartmeta = self.chartmeta

	if not settings:getBoolean(Settings.keys.replay_base.auto_timings) then
		return
	end

	local timings = chartmeta.timings
	if not timings then
		local format_config = assert(format_timings[chartmeta.format], "unknown chart format")
		local name = format_config[1]
		local timing_key = Settings.keys.timings[name]
		timings = Timings(name, timing_key and settings:getNumber(timing_key) or nil)
	end

	replayBase.timings = chartmeta.timings and nil or timings

	---@type sea.Subtimings?
	local subtimings
	if timings.name == "osuod" then
		subtimings = Subtimings("scorev", settings:getNumber(Settings.keys.timings.osu_score_version))
	end
	replayBase.subtimings = subtimings
	replayBase.timing_values = assert(TimingValuesFactory:get(timings, subtimings))
end

return GameplayTimings
