local TimingSystem = require("rizu.engine.scoring.TimingSystem")
local TimingValues = require("sea.chart.TimingValues")

---One window of the given size in seconds, counted with normalscore.
---@class rizu.engine.scoring.systems.Simple : rizu.engine.scoring.TimingSystem
---@operator call: rizu.engine.scoring.systems.Simple
local Simple = TimingSystem + {}

Simple.name = "simple"
Simple.label = "Simple"

---@param timings sea.Timings
function Simple:getName(timings)
	return ("Simple %gms"):format(timings.data * 1000)
end

---@param timings sea.Timings
function Simple:newTimingValues(timings)
	return TimingValues():setSimple(timings.data)
end

return Simple()
