local TimingSystem = require("rizu.engine.scoring.TimingSystem")
local TimingValues = require("sea.chart.TimingValues")

---Timings this version does not know, counted with normalscore.
---@class rizu.engine.scoring.systems.Unknown : rizu.engine.scoring.TimingSystem
---@operator call: rizu.engine.scoring.systems.Unknown
local Unknown = TimingSystem + {}

Unknown.name = "unknown"
Unknown.label = "Unknown"

function Unknown:newTimingValues()
	return TimingValues():setSimple(0, 0)
end

return Unknown()
