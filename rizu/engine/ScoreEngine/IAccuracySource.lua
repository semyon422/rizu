local class = require("class")

---@class rizu.IAccuracySource
---@operator call: rizu.IAccuracySource
local IAccuracySource = class()

IAccuracySource.accuracy_multiplier = 1
IAccuracySource.accuracy_format = "%0.02f"

---@return number
function IAccuracySource:getAccuracy()
	error("not implemented")
end

---@return string
function IAccuracySource:getAccuracyString()
	return self.accuracy_format:format(self:getAccuracy() * self.accuracy_multiplier)
end

return IAccuracySource
