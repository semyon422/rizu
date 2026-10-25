local class = require("class")
local Settings = require("rizu.config.Settings")
local StoredAccuracies = require("rizu.engine.ScoreEngine.StoredAccuracies")
local Scoring = require("rizu.engine.scoring.Scoring")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")

---@class rizu.GameplayTimings
---@operator call: rizu.GameplayTimings
local GameplayTimings = class()

---The score system picked in the play config, nil for the chart's auto timings.
---@param settings rizu.config.Config
---@return rizu.engine.scoring.Scoring?
function GameplayTimings.getPicked(settings)
	local token = settings:getString(Settings.keys.select.accuracy_system)
	for _, stored in ipairs(StoredAccuracies.parse(settings:getString(Settings.keys.scores.stored_accuracies))) do
		if stored == token then
			return StoredAccuracies.getScoring(token)
		end
	end
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
