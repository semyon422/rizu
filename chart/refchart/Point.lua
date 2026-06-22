local class = require("class")

---@class refchart.Point
---@operator call: refchart.Point
---@field time number
---@field tempo number?
---@field measure {[1]: integer, [2]: integer}?
local Point = class()

---@param p chart.AbsolutePoint
function Point:new(p)
	self.time = p.absoluteTime
	if p._tempo then
		self.tempo = p._tempo.tempo
	end
	if p._measure then
		local offset = p._measure.offset
		self.measure = {offset[1], offset[2]}
	end
end

return Point
