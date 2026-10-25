local class = require("class")
local Settings = require("rizu.config.Settings")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local Scoring = require("rizu.engine.scoring.Scoring")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")

---@class rizu.GameplayTimings
---@operator call: rizu.GameplayTimings
local GameplayTimings = class()

---The score system picked in the play config, nil while auto timings are on.
---@param settings rizu.config.Config
---@return rizu.engine.scoring.Scoring?
function GameplayTimings.getPicked(settings)
	local keys = Settings.keys
	if settings:getBoolean(keys.replay_base.auto_timings) then
		return
	end
	local name = settings:getChoice(keys.timings.system) --[[@as sea.TimingsName]]
	local value_key = keys.timings[name]
	local value = value_key and settings:getNumber(value_key) or nil
	local subtimings ---@type sea.Subtimings?
	if name == "osuod" then
		-- Slider arithmetic leaves values such as 7.7 just off the exact tenth Timings requires.
		value = math.floor(value * 10 + 0.5) / 10
		subtimings = Subtimings("scorev", settings:getNumber(keys.timings.osu_score_version))
	end
	return Scoring(Timings(name, value), subtimings)
end

---@param chartmeta sea.Chartmeta
function GameplayTimings:new(chartmeta)
	self.chartmeta = chartmeta
end

---@param replayBase sea.ReplayBase
---@param picked rizu.engine.scoring.Scoring? See getPicked(). The chart's auto timings when nil.
function GameplayTimings:apply(replayBase, picked)
	local chartmeta = self.chartmeta
	local scoring = picked or Scoring(TimingSystems.getAuto(chartmeta.timings, chartmeta.format))
	-- Timings of the chart itself are not repeated in the replay.
	replayBase.timings = (picked or not chartmeta.timings) and scoring.timings or nil
	replayBase.subtimings = scoring.subtimings
	replayBase.timing_values = assert(scoring:getTimingValues())
	replayBase.nearest = scoring:isNearest()
end

return GameplayTimings
