local Layer = require("chart.model.layers.Layer")
local MeasurePoint = require("chart.model.tp.MeasurePoint")
local MeasureCompute = require("chart.model.compute.MeasureCompute")

---@class chart.MeasureLayer: chart.Layer
---@operator call: chart.MeasureLayer
local MeasureLayer = Layer + {}

function MeasureLayer:new()
	Layer.new(self)
	self.measureCompute = MeasureCompute()
end

---@param mode string
function MeasureLayer:setSignatureMode(mode)
	assert(mode == "long" or mode == "short", "Wrong signature mode")
	self.signatureMode = mode
end

---@param time chart.Fraction
---@param isRightSide boolean?
---@return chart.MeasurePoint
function MeasureLayer:newPoint(time, isRightSide)
	return MeasurePoint(time, isRightSide)
end

---@param time chart.Fraction
---@param isRightSide boolean?
---@return chart.MeasurePoint
function MeasureLayer:getPoint(time, isRightSide)
	---@type chart.MeasurePoint
	return Layer.getPoint(self, time, isRightSide)
end

function MeasureLayer:compute()
	self.measureCompute:compute(self:getPointList())
	Layer.compute(self)
end

function MeasureLayer:toInterval()
	local MeasureInterval = require("chart.model.convert.MeasureInterval")
	local conv = MeasureInterval()
	conv:convert(self)
end

function MeasureLayer:toAbsolute()
	local IntervalAbsolute = require("chart.model.convert.IntervalAbsolute")
	self:toInterval()
	---@cast self -chart.MeasureLayer, +chart.IntervalLayer
	local conv2 = IntervalAbsolute()
	conv2:convert(self)
end

return MeasureLayer
