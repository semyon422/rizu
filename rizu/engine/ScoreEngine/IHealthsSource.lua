local class = require("class")

---@class rizu.IHealthsSource
---@operator call: rizu.IHealthsSource
local IHealthsSource = class()

---@return number
function IHealthsSource:getHealths()
	error("not implemented")
end

---@return number
function IHealthsSource:getMaxHealths()
	error("not implemented")
end

---The gauge is dead, the play cannot be saved anymore.
---@return boolean
function IHealthsSource:isFailed()
	error("not implemented")
end

---The play counts as passed if it ended now. A gauge can be alive and still not enough, such as LR2's groove below 80.
---@return boolean
function IHealthsSource:isPassed()
	return not self:isFailed()
end

return IHealthsSource
