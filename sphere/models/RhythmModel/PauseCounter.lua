local class = require("class")

---@class sphere.PauseCounter
---@operator call: sphere.PauseCounter
local PauseCounter = class()

---@param timeEngine sphere.TimeEngine
function PauseCounter:new(timeEngine)
	self.timeEngine = timeEngine
end

function PauseCounter:load()
	self.count = 0
	self.paused = false
end

---@param start_time number
---@param duration number
function PauseCounter:setPlayTime(start_time, duration)
	self.minTime = start_time
	self.maxTime = start_time + duration
end

function PauseCounter:update()
	local timeEngine = self.timeEngine
	local timer = timeEngine.timer
	local currentTime = timeEngine.currentTime

	if currentTime < self.minTime or currentTime > self.maxTime then
		return
	end
	if not timer.is_playing and not self.paused then
		self.paused = true
		self.count = self.count + 1
	elseif timer.is_playing and self.paused then
		self.paused = false
	end
end

return PauseCounter
