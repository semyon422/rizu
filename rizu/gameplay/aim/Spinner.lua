local class = require("class")

---@class rizu.aim.Spinner
---@operator call: rizu.aim.Spinner
---@field last_angle number?
---@field last_time number?
local Spinner = class()

Spinner.center_x = 256
Spinner.center_y = 192
Spinner.dead_radius = 16
Spinner.max_turns_per_second = 8

---@param object chart.osu.AimObject
---@param od number
function Spinner:new(object, od)
	self.start_time = object.time
	self.end_time = assert(object.end_time)
	self.required_turns = (self.end_time - self.start_time) * (1.5 + 0.15 * od)
	self.angle_sum = 0
end

function Spinner:resetSample()
	self.last_angle, self.last_time = nil, nil
end

---@return number
function Spinner:getTurns()
	return math.abs(self.angle_sum) / (2 * math.pi)
end

---@param time number
---@param x number
---@param y number
---@param held boolean
---@param paused boolean
function Spinner:receive(time, x, y, held, paused)
	local dx, dy = x - self.center_x, y - self.center_y
	if paused or not held or time < self.start_time or time > self.end_time or dx * dx + dy * dy < self.dead_radius ^ 2 then
		self:resetSample()
		return
	end
	local angle = math.atan2(dy, dx)
	if self.last_angle and self.last_time and time > self.last_time then
		local delta = (angle - self.last_angle + math.pi) % (2 * math.pi) - math.pi
		local limit = (time - self.last_time) * self.max_turns_per_second * 2 * math.pi
		self.angle_sum = self.angle_sum + math.max(-limit, math.min(limit, delta))
	end
	self.last_angle, self.last_time = angle, time
end

return Spinner
