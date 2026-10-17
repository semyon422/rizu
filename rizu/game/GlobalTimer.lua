local ITimer = require("time.ITimer")

---@class rizu.GlobalTimer: time.ITimer
---@operator call: rizu.GlobalTimer
local GlobalTimer = ITimer + {}

GlobalTimer.time = 0

---@param time number
function GlobalTimer:setTime(time)
	self.time = time
end

---@return number
function GlobalTimer:getTime()
	return self.time
end

return GlobalTimer
