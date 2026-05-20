local Intervals = require("chart.chartedit.Intervals")
local Points = require("chart.chartedit.Points")
local Fraction = require("chart.core.Fraction")

local test = {}

function test.split_middle(t)
	local points = Points()
	points:initDefault()
	local intervals = Intervals(points)

	points:interpolateAbsolute(16, 0.25)
	local p1 = points:saveSearchPoint()

	points:interpolateAbsolute(16, 0.75)
	local p2 = points:saveSearchPoint()

	points:interpolateAbsolute(16, 0.5)
	local p = points:saveSearchPoint()

	intervals:splitVertex(p)
	t:eq(p.vertex.offset, 0.5)
	t:eq(p.time, Fraction(1, 2))
	t:eq(p.absoluteTime, 0.5)

	t:eq(p.vertex.prev.offset, 0)
	t:eq(p.vertex.next.offset, 1)

	t:eq(p1.vertex.offset, 0)
	t:eq(p2.vertex.offset, 0.5)

	intervals:mergeVertex(p)

	t:eq(p1.vertex.offset, 0)
	t:eq(p2.vertex.offset, 0)
end

function test.split_before(t)
	local points = Points()
	points:initDefault()
	local intervals = Intervals(points)

	points:interpolateAbsolute(16, -0.75)
	local p1 = points:saveSearchPoint()

	points:interpolateAbsolute(16, -0.25)
	local p2 = points:saveSearchPoint()

	points:interpolateAbsolute(16, -0.5)
	local p = points:saveSearchPoint()

	intervals:splitVertex(p)
	t:eq(p.vertex.offset, -0.5)
	t:eq(p.time, Fraction(1, 2))
	t:eq(p.absoluteTime, -0.5)
	t:eq(p.prev, p1)
	t:eq(p.next, p2)

	t:eq(p.vertex.prev, nil)
	t:eq(p.vertex.next.offset, 0)

	t:eq(p1.vertex.offset, -0.5)
	t:eq(p2.vertex.offset, -0.5)

	intervals:mergeVertex(p)

	t:eq(p1.vertex.offset, 0)
	t:eq(p2.vertex.offset, 0)
end

function test.split_after(t)
	local points = Points()
	points:initDefault()
	local intervals = Intervals(points)

	points:interpolateAbsolute(16, 1.25)
	local p1 = points:saveSearchPoint()

	points:interpolateAbsolute(16, 1.75)
	local p2 = points:saveSearchPoint()

	points:interpolateAbsolute(16, 1.5)
	local p = points:saveSearchPoint()

	intervals:splitVertex(p)
	t:eq(p.vertex.offset, 1.5)
	t:eq(p.time, Fraction(1, 2))
	t:eq(p.absoluteTime, 1.5)
	t:eq(p.prev, p1)
	t:eq(p.next, p2)

	t:eq(p.vertex.prev.offset, 1)
	t:eq(p.vertex.next, nil)

	t:eq(p1.vertex.offset, 1)
	t:eq(p2.vertex.offset, 1.5)

	intervals:mergeVertex(p)

	t:eq(p1.vertex.offset, 1)
	t:eq(p2.vertex.offset, 1)
end

function test.split_after_merge_before(t)
	local points = Points()
	points:initDefault()
	local intervals = Intervals(points)

	points:interpolateAbsolute(16, 0.25)
	local p25 = points:saveSearchPoint()

	points:interpolateAbsolute(16, 0.5)
	local p50 = points:saveSearchPoint()

	points:interpolateAbsolute(16, 0.75)
	local p75 = points:saveSearchPoint()

	local p0 = p25.prev
	local p100 = p75.next
	---@cast p0 -?
	---@cast p100 -?

	t:assert(p0._vertex)
	t:assert(p100._vertex)

	intervals:splitVertex(p50)

	t:eq(p0.vertex, p0._vertex)
	t:eq(p25.vertex, p0._vertex)
	t:eq(p50.vertex, p50._vertex)
	t:eq(p75.vertex, p50._vertex)
	t:eq(p100.vertex, p100._vertex)

	intervals:mergeVertex(p0)

	t:eq(p0.vertex, p50._vertex)
	t:eq(p25.vertex, p50._vertex)
	t:eq(p50.vertex, p50._vertex)
	t:eq(p75.vertex, p50._vertex)
	t:eq(p100.vertex, p100._vertex)

	intervals:splitVertex(p0)

	t:eq(p0.vertex, p0._vertex)
	t:eq(p25.vertex, p0._vertex)
	t:eq(p50.vertex, p50._vertex)
	t:eq(p75.vertex, p50._vertex)
	t:eq(p100.vertex, p100._vertex)
end

---@param t testing.T
function test.beats(t)
	local points = Points()
	points:initDefault()

	local p0 = points:getFirstPoint()
	local p10 = points:getLastPoint()
	---@cast p0 -?
	---@cast p10 -?

	points:interpolateAbsolute(16, -1.5)
	local p_15 = points:saveSearchPoint()

	points:interpolateAbsolute(16, 3.5)
	local p35 = points:saveSearchPoint()

	local intervals = Intervals(points)

	intervals:splitVertex(p_15)
	intervals:splitVertex(p35)

	t:eq(p_15._vertex.beats, 2)
	t:eq(p0._vertex.beats, 1)
	t:eq(p10._vertex.beats, 2)
	t:eq(p35._vertex.beats, 1)
end

return test
