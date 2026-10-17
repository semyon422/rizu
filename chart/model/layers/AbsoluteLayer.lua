local Layer = require("chart.model.layers.Layer")
local AbsolutePoint = require("chart.model.tp.AbsolutePoint")
local AbsoluteCompute = require("chart.model.compute.AbsoluteCompute")

---@class chart.AbsoluteLayer: chart.Layer
---@operator call: chart.AbsoluteLayer
local AbsoluteLayer = Layer + {}

function AbsoluteLayer:new()
	Layer.new(self)
	self.absoluteCompute = AbsoluteCompute()
end

---@param time number
---@return chart.AbsolutePoint
function AbsoluteLayer:newPoint(time)
	return AbsolutePoint(time)
end

---@param time number
---@return chart.AbsolutePoint
function AbsoluteLayer:getPoint(time)
	---@type chart.AbsolutePoint
	return Layer.getPoint(self, time)
end

function AbsoluteLayer:compute()
	self.absoluteCompute:compute(self:getPointList())
	Layer.compute(self)
end

function AbsoluteLayer:toInterval()
	local AbsoluteInterval = require("chart.model.convert.AbsoluteInterval")
	local conv = AbsoluteInterval()
	conv:convert(self)
end

return AbsoluteLayer
