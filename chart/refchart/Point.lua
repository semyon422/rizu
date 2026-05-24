local class = require("class")

---@class refchart.Point
---@operator call: refchart.Point
---@field time number
---@field tempo number?
---@field measure chart.Fraction?
local Point = class()

---@param p chart.AbsolutePoint
function Point:new(p)
	self.time = p.absoluteTime
	if p._tempo then
		self.tempo = p._tempo.tempo
	end
	if p._measure then
		self.measure = p._measure.offset
	end
end

return Point
