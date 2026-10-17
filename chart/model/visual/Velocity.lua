local class = require("class")

---@class chart.Velocity
---@operator call: chart.Velocity
local Velocity = class()

Velocity.currentSpeed = 1
Velocity.localSpeed = 1
Velocity.globalSpeed = 1

---@param currentSpeed number
---@param localSpeed number
---@param globalSpeed number
function Velocity:new(currentSpeed, localSpeed, globalSpeed)
	assert(not currentSpeed or type(currentSpeed) == "number")
	assert(not localSpeed or type(localSpeed) == "number")
	assert(not globalSpeed or type(globalSpeed) == "number")
	self.currentSpeed = currentSpeed
	self.localSpeed = localSpeed
	self.globalSpeed = globalSpeed
end

---@param a chart.Velocity
---@return string
function Velocity.__tostring(a)
	return ("Velocity(%s,%s,%s)"):format(a.currentSpeed, a.localSpeed, a.globalSpeed)
end

return Velocity
