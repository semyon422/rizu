local class = require("class")

---@class rizu.PauseCounter
---@operator call: rizu.PauseCounter
local PauseCounter = class()

function PauseCounter:new()
	self.count = 0
	self.paused = false
end

---@param start_time number
---@param duration number
function PauseCounter:setPlayTime(start_time, duration)
	self.start_time = start_time
	self.duration = duration
end

---@param time number
---@return boolean
function PauseCounter:check(time)
	return time >= self.start_time and time <= self.start_time + self.duration
end

function PauseCounter:pause()
	self.paused = true
end

---@param time number
function PauseCounter:play(time)
	if self.paused and self:check(time) then
		self.count = self.count + 1
	end
	self.paused = false
end

return PauseCounter
