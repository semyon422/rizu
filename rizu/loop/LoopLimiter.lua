local class = require("class")
local LoveSleepFunction = require("rizu.loop.sleep.LoveSleepFunction")

---@class rizu.loop.LoopLimiter
---@operator call: rizu.loop.LoopLimiter
local LoopLimiter = class()

---@param loop rizu.Loop
function LoopLimiter:new(loop)
	self.loop = loop
	self.fps_limit = 240
	self.unlimited_fps = false
	self.busy_loop_ratio = 0
	self.target_time = 0
	---@type rizu.ISleepFunction
	self.sleep_function = LoveSleepFunction()
end

---@param time number
function LoopLimiter:reset(time)
	self.target_time = time
end

---@return boolean
function LoopLimiter:shouldSleep()
	return self.fps_limit > 0 and not self.unlimited_fps
end

---@param frame_end_time number
---@return number, number
function LoopLimiter:limit(frame_end_time)
	if not self:shouldSleep() then
		return frame_end_time, 0
	end

	self.target_time = math.max(self.target_time + 1 / self.fps_limit, frame_end_time)
	local frame_time = 1 / self.fps_limit
	local busy_time = self.busy_loop_ratio * frame_time
	local to_sleep = self.target_time - frame_end_time - busy_time

	return self.target_time, to_sleep
end

---@param to_sleep number
function LoopLimiter:sleep(to_sleep)
	if to_sleep > 0 then
		self.sleep_function:sleep(to_sleep)
	end
end

function LoopLimiter:busyWait(target_time)
	if self.busy_loop_ratio > 0 then
		while love.timer.getTime() < target_time do end
	end
end

return LoopLimiter
