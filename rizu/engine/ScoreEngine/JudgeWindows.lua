local class = require("class")

---@class rizu.JudgeWindows
---@operator call: rizu.JudgeWindows
local JudgeWindows = class()

---@param windows number[]
function JudgeWindows:new(windows)
	self.windows = windows
end

---@param dt number
---@return integer?
function JudgeWindows:get(dt)
	dt = math.abs(dt)

	local windows = self.windows
	for i, w in ipairs(windows) do
		if dt <= w then
			return i
		end
	end
end

return JudgeWindows
