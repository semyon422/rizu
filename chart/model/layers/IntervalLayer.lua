local Layer = require("chart.model.layers.Layer")
local IntervalPoint = require("chart.model.tp.IntervalPoint")
local IntervalCompute = require("chart.model.compute.IntervalCompute")

---@class chart.IntervalLayer: chart.Layer
---@operator call: chart.IntervalLayer
local IntervalLayer = Layer + {}

function IntervalLayer:new()
	Layer.new(self)
	self.intervalCompute = IntervalCompute()
end

---@param time chart.Fraction
---@return chart.IntervalPoint
function IntervalLayer:newPoint(time)
	return IntervalPoint(time)
end

---@param time chart.Fraction
---@return chart.IntervalPoint
function IntervalLayer:getPoint(time)
	---@type ncdk2.IntervalPoint
	return Layer.getPoint(self, time)
end

function IntervalLayer:compute()
	self.intervalCompute:compute(self:getPointList())
	Layer.compute(self)
end

function IntervalLayer:toAbsolute()
	local IntervalAbsolute = require("chart.model.convert.IntervalAbsolute")
	local conv = IntervalAbsolute()
	conv:convert(self)
end

return IntervalLayer
