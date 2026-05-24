local class = require("class")

---@class rizu.VisualInfo
---@operator call: rizu.VisualInfo
---@field time number
---@field rate number
---@field shortening number
---@field const boolean
---@field logic_notes {[chart.LinkedNote]: rizu.LogicNote?}
local VisualInfo = class()

function VisualInfo:new()
	self.time = 0
	self.rate = 1
	self.shortening = 0
	self.const = false
	self.logic_notes = {}
end

---@return number
function VisualInfo:getTime()
	return self.time
end

---@param time number
---@return number
function VisualInfo:sub(time)
	return (self:getTime() - time) * self.rate
end

return VisualInfo
