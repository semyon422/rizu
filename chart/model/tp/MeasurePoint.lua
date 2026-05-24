local Point = require("chart.model.tp.Point")

---@class chart.MeasurePoint: chart.Point
---@operator call: chart.MeasurePoint
---@field _signature chart.Signature?
---@field signature chart.Fraction?
---@field _tempo chart.Tempo?
---@field tempo chart.Tempo?
---@field _stop chart.Stop?
---@field beatTime chart.Fraction?
local MeasurePoint = Point + {}

-- Stop should be placed on isRightSide = false
-- In this case isRightSide = true time point should be created
MeasurePoint.isRightSide = false

---@param measureTime chart.Fraction
---@param isRightSide boolean?
function MeasurePoint:new(measureTime, isRightSide)
	self.measureTime = measureTime
	self.isRightSide = isRightSide
end

---@param a chart.MeasurePoint
---@return string
function MeasurePoint.__tostring(a)
	return ("MeasurePoint(%s,%s)"):format(a.measureTime, a.isRightSide)
end

---@return number
function MeasurePoint:getBeatModulo()
	return self.beatTime % 1
end

---@return number
function MeasurePoint:getBeatDuration()
	return self.tempo:getBeatDuration()
end

---@param a chart.MeasurePoint
---@param b chart.MeasurePoint
---@return boolean
function MeasurePoint.__eq(a, b)
	local at, bt = a.measureTime, b.measureTime
	return at == bt and a.isRightSide == b.isRightSide
end

---@param a chart.MeasurePoint
---@param b chart.MeasurePoint
---@return boolean
function MeasurePoint.__lt(a, b)
	local at, bt = a.measureTime, b.measureTime
	return at < bt or
		at == bt and a.isRightSide == false and b.isRightSide == true
end

---@param a chart.MeasurePoint
---@param b chart.MeasurePoint
---@return boolean
function MeasurePoint.__le(a, b)
	local at, bt = a.measureTime, b.measureTime
	return at < bt or
		at == bt and a.isRightSide == false and b.isRightSide == true or
		at == bt and a.isRightSide == b.isRightSide
end

return MeasurePoint
