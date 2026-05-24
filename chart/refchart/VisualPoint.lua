local class = require("class")

---@class refchart.VisualPoint
---@operator call: refchart.VisualPoint
---@field point integer
---@field expand number?
---@field velocity number[]?
local VisualPoint = class()

---@param vp chart.VisualPoint
---@param p_index integer
function VisualPoint:new(vp, p_index)
	self.point = p_index
	if vp._expand then
		self.expand = vp._expand.duration
	end
	if vp._velocity then
		self.velocity = {
			vp._velocity.currentSpeed,
			vp._velocity.localSpeed,
			vp._velocity.globalSpeed,
		}
	end
end

return VisualPoint
