--- Performance calculator stub for testing.
---
--- Returns fixed PP and star rating values.

local class = require("class")

---@class bancho.stub.PerformanceCalculator
local PerformanceCalculator = class()

function PerformanceCalculator:new(fixed_pp, fixed_sr)
	self._fixed_pp = fixed_pp or 50.0
	self._fixed_sr = fixed_sr or 3.0
	return self
end

--- Calculate performance for a score.
---@param score table score data
---@return number pp
---@return number sr
function PerformanceCalculator:calculate(score)
	return self._fixed_pp, self._fixed_sr
end

return PerformanceCalculator
