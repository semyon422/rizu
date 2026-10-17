local class = require("class")

---@class chart.IntervalCompute
---@operator call: chart.IntervalCompute
local IntervalCompute = class()

---@param points chart.IntervalPoint[]
---@return chart.Measure?
function IntervalCompute:getFirstMeasure(points)
	for _, p in ipairs(points) do
		if p._measure then
			return p._measure
		end
	end
end

---@param points chart.IntervalPoint[]
function IntervalCompute:compute(points)
	local measure = self:getFirstMeasure(points)

	---@type chart.Vertex[]
	local intervals = {}
	for _, p in ipairs(points) do
		if p._vertex then
			table.insert(intervals, p._vertex)
			p._vertex.point = p
		end
	end

	for i = 1, #intervals - 1 do
		local interval = intervals[i]
		local next_interval = intervals[i + 1]
		interval.next, next_interval.prev = next_interval, interval
	end

	local interval = intervals[1]
	for _, point in ipairs(points) do
		if point._measure then
			measure = point._measure
		end

		local _vertex = point._vertex
		if _vertex then
			interval = _vertex
		end

		point.vertex = interval
		point.measure = measure
	end

	for _, point in ipairs(points) do
		point.absoluteTime = point:tonumber()
	end
end

return IntervalCompute
