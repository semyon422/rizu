local IntervalCompute = require("ncdk2.compute.IntervalCompute")
local IntervalPoint = require("ncdk2.tp.IntervalPoint")
local Vertex = require("ncdk2.to.Interval")
local Fraction = require("ncdk.Fraction")

local test = {}

---@param n number
---@return ncdk2.IntervalPoint
local function newp(n)
	return IntervalPoint(Fraction(n, 1000, true))
end

function test.basic2(t)
	local conv = IntervalCompute()

	local points = {
		newp(0),
		newp(1),
		newp(2),
		newp(3),
		newp(4),
		newp(5),
	}

	local int_0 = Vertex(0)
	local int_4 = Vertex(4)
	points[1]._vertex = int_0
	points[5]._vertex = int_4

	conv:compute(points)

	t:eq(points[1].absoluteTime, 0)
	t:eq(points[2].absoluteTime, 1)
	t:eq(points[5].absoluteTime, 4)
	t:eq(points[6].absoluteTime, 5)

	t:assert(not int_0.prev)
	t:assert(not int_4.next)
	t:eq(int_0.next, int_4)
	t:eq(int_0, int_4.prev)
end

return test
