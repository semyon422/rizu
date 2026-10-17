local class = require("class")
local math_util = require("math_util")

---@class rizu.PlayProgress
---@operator call: rizu.PlayProgress
local PlayProgress = class()

function PlayProgress:new()
	self.init_time = 0
	self.start_time = 0
	self.duration = 1
end

---@param time number
---@return number
function PlayProgress:get(time)
	local start_time = self.start_time

	local a, b, c, d = start_time, start_time + self.duration, 0, 1
	if time < a then
		a, b, c, d = self.init_time, a, -1, 0
	end

	return math_util.clamp(math_util.map(time, a, b, c, d), -1, 1)
end

return PlayProgress
