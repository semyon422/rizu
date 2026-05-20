local Points = require("chart.chartedit.Points")
local Intervals = require("chart.chartedit.Intervals")
local Fraction = require("chart.core.Fraction")

local test = {}

function test.int_abs(t)
	local points = Points()
	points:initDefault()

	local p = points:interpolateAbsolute(16, 0.5)
	t:eq(p.vertex.offset, 0)
	t:eq(p.time, Fraction(1, 2))
	t:eq(p.absoluteTime, 0.5)
	t:eq(p.prev, p.vertex.point)
	t:eq(p.next, p.vertex.next.point)

	p = points:interpolateAbsolute(16, -0.5)
	t:eq(p.vertex.offset, 0)
	t:eq(p.time, Fraction(-1, 2))
	t:eq(p.absoluteTime, -0.5)
	t:eq(p.prev, nil)
	t:eq(p.next, p.vertex.point)

	p = points:interpolateAbsolute(16, 1.5)
	t:eq(p.vertex.offset, 1)
	t:eq(p.time, Fraction(1, 2))
	t:eq(p.absoluteTime, 1.5)
	t:eq(p.prev, p.vertex.point)
	t:eq(p.next, nil)
end

function test.new_points(t)
	local points = Points()
	points:initDefault()

	local p0 = points:getFirstPoint()
	local p10 = p0.next

	points:interpolateAbsolute(10, 0.5)
	local p5 = points:saveSearchPoint()

	t:eq(p0.next, p5)
	t:eq(p10.prev, p5)
	t:eq(p5.next, p10)
	t:eq(p5.prev, p0)

	points:interpolateAbsolute(10, 0.2)
	local p2 = points:saveSearchPoint()

	t:eq(p0.next, p2)
	t:eq(p5.prev, p2)
	t:eq(p2.next, p5)
	t:eq(p2.prev, p0)
end

function test.remove_point(t)
	local points = Points()
	points:initDefault()

	local p0 = points:getFirstPoint()
	local p10 = p0.next

	points:interpolateAbsolute(10, 0.5)
	local p5 = points:saveSearchPoint()

	points:removePoint(p5)

	t:eq(p0.next, p10)
	t:eq(p10.prev, p0)
end

function test.int_frac(t)
	local points = Points()
	points:initDefault()

	local vertex = points:getFirstPoint().vertex

	local p = points:interpolateFraction(vertex, Fraction(1, 2))
	t:eq(p.absoluteTime, 0.5)

	p = points:interpolateFraction(vertex, Fraction(-1, 2))
	t:eq(p.absoluteTime, -0.5)

	p = points:interpolateFraction(vertex.next, Fraction(1, 2))
	t:eq(p.absoluteTime, 1.5)
end

function test.int_close_to(t)
	local points = Points()
	points:initDefault()

	local p0 = points:getFirstPoint()
	local p100 = points:getLastPoint()

	local intervals = Intervals(points)
	intervals:moveVertex(p0._vertex.next, 10)
	intervals:updateVertex(p0._vertex, 10)

	points:interpolateAbsolute(16, 2.5)
	local p25 = points:saveSearchPoint()

	intervals:splitVertex(p25)

	local p = points:interpolateAbsolute(16, 2.501)
	t:eq(p.vertex.offset, 2.5)
	t:eq(p.time, Fraction(1, 2))
	t:eq(p.absoluteTime, 2.5)

	p = points:interpolateAbsolute(16, 2.499)
	t:eq(p.vertex.offset, 2.5)
	t:eq(p.time, Fraction(1, 2))
	t:eq(p.absoluteTime, 2.5)

	p = points:interpolateAbsolute(16, 2.25)
	t:eq(p.vertex.offset, 0)
	t:eq(p.time, Fraction(9, 4))
	t:eq(p.absoluteTime, 2.25)
end

---@param t testing.T
function test.global_time(t)
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

	points:interpolateAbsolute(16, 5)
	local p50 = points:saveSearchPoint()

	local intervals = Intervals(points)

	intervals:splitVertex(p35)

	t:eq(p_15:getGlobalTime(), Fraction(-3, 2))
	t:eq(p0:getGlobalTime(), Fraction(0))
	t:eq(p10:getGlobalTime(), Fraction(1))
	t:eq(p35:getGlobalTime(), Fraction(7, 2))
	t:eq(p50:getGlobalTime(), Fraction(5))
end

return test
