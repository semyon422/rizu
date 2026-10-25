local class = require("class")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")

---@class rizu.GameplayTimings
---@operator call: rizu.GameplayTimings
local GameplayTimings = class()

---@param chartmeta sea.Chartmeta
function GameplayTimings:new(chartmeta)
	self.chartmeta = chartmeta
end

---Every mania play is judged with auto timings for now, see TimingSystems.getAuto().
---@param replayBase sea.ReplayBase
function GameplayTimings:apply(replayBase)
	local chartmeta = self.chartmeta
	local timings, subtimings = TimingSystems.getAuto(chartmeta.timings, chartmeta.format)
	-- Timings of the chart itself are not repeated in the replay.
	replayBase.timings = not chartmeta.timings and timings or nil
	replayBase.subtimings = subtimings
	replayBase.timing_values = assert(TimingValuesFactory:get(timings, subtimings))
	replayBase.nearest = TimingSystems.get(timings.name):isNearest(subtimings)
end

return GameplayTimings
