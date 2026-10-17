local Point = require("chart.model.tp.Point")

---@class chart.AbsolutePoint: chart.Point
---@operator call: chart.AbsolutePoint
---@field _tempo chart.Tempo?
---@field tempo chart.Tempo?
---@field _measure chart.Measure?
---@field measure chart.Measure?
local AbsolutePoint = Point + {}

---@param a chart.AbsolutePoint
---@return string
function AbsolutePoint.__tostring(a)
	return ("AbsolutePoint(%s)[%s]"):format(a.absoluteTime, a:getAbsoluteTimeKey())
end

---@return number
function AbsolutePoint:getBeatModulo()
	local tempo = self.tempo
	if not tempo then
		return 0
	end
	local measure = self.measure
	local measure_offset = measure and measure.offset or 0
	local beat_time = (self.absoluteTime - tempo.point.absoluteTime) / tempo:getBeatDuration()
	return (beat_time + measure_offset) % 1
end

---@return number
function AbsolutePoint:getBeatDuration()
	local tempo = self.tempo
	if not tempo then
		return math.huge
	end
	return tempo:getBeatDuration()
end

AbsolutePoint.__eq = Point.__eq
AbsolutePoint.__lt = Point.__lt
AbsolutePoint.__le = Point.__le

return AbsolutePoint
