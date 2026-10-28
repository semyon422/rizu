local class = require("class")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")

---@class sea.TimingValuesFactory
---@operator call: sea.TimingValuesFactory
local TimingValuesFactory = class()

---@param t sea.Timings
---@param st sea.Subtimings?
---@return sea.TimingValues?
---@return string?
function TimingValuesFactory:get(t, st)
	return TimingSystems.get(t.name):getTimingValues(t, st)
end

return TimingValuesFactory
