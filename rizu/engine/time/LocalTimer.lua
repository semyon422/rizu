local class = require("class")

---@class rizu.LocalTimer
---@operator call: rizu.LocalTimer
---@field global_time number?
---@field global_offset number?
local LocalTimer = class()

LocalTimer.is_playing = false
LocalTimer.offset = 0
LocalTimer.rate = 1
LocalTimer.mono_offset = -math.huge

---@return number
function LocalTimer:assertGlobalTime()
	return assert(self.global_time, "timer not initialized")
end

---@return number?
function LocalTimer:getGlobalTime()
	return self.global_time
end

---@param global_time number
function LocalTimer:setGlobalTime(global_time)
	self.global_time = global_time
end

---@private
---@return number
function LocalTimer:getDeltaGlobalTime()
	if not self.is_playing then
		return 0
	end
	return self:assertGlobalTime() - self.global_offset
end

---@param no_mono boolean?
---@return number
function LocalTimer:getTime(no_mono)
	local dt = self:getDeltaGlobalTime()
	local time = dt * self.rate + self.offset
	if no_mono then
		return time
	end
	return math.max(time, self.mono_offset)
end

---@param global_time number
---@return number
function LocalTimer:transform(global_time)
	return (global_time - self:assertGlobalTime()) * self.rate + self:getTime()
end

---@param time number?
---@param reset boolean?
function LocalTimer:setTime(time, reset)
	self.mono_offset = not reset and math.max(self.mono_offset, self:getTime()) or -math.huge
	self.offset = time or self:getTime(true)
	self.global_offset = self:getGlobalTime()
end

---@param rate number
function LocalTimer:setRate(rate)
	self:setTime()
	self.rate = rate
end

function LocalTimer:pause()
	if not self.is_playing then
		return
	end

	self:assertGlobalTime()
	self:setTime()
	self.is_playing = false
end

function LocalTimer:play()
	if self.is_playing then
		return
	end

	self:assertGlobalTime()
	self:setTime()
	self.is_playing = true
end

return LocalTimer
