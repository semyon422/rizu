local class = require("class")

---@class chart.AbsoluteCompute
---@operator call: chart.AbsoluteCompute
local AbsoluteCompute = class()

---@param points chart.MeasurePoint[]
---@return chart.Tempo?
function AbsoluteCompute:getFirstTempo(points)
	for _, p in ipairs(points) do
		if p._tempo then
			return p._tempo
		end
	end
end

---@param points chart.IntervalPoint[]
---@return chart.Measure?
function AbsoluteCompute:getFirstMeasure(points)
	for _, p in ipairs(points) do
		if p._measure then
			return p._measure
		end
	end
end

---@param points chart.AbsolutePoint[]
function AbsoluteCompute:compute(points)
	local tempo = self:getFirstTempo(points)
	local measure = self:getFirstMeasure(points)

	for _, point in ipairs(points) do
		local _tempo = point._tempo
		if _tempo then
			_tempo.point = point
			tempo = _tempo
		end

		if point._measure then
			measure = point._measure
		end

		point.tempo = tempo
		point.measure = measure
	end
end

return AbsoluteCompute
