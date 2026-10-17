local MeasureCompute = require("chart.model.compute.MeasureCompute")
local MeasurePoint = require("chart.model.tp.MeasurePoint")
local Tempo = require("chart.model.to.Tempo")
local Stop = require("chart.model.to.Stop")
local Signature = require("chart.model.to.Signature")
local Fraction = require("chart.core.Fraction")

local test = {}

---@param n number
---@return chart.MeasurePoint
local function newp(n)
	return MeasurePoint(Fraction(n, 1000, true))
end

function test.basic(t)
	local conv = MeasureCompute()

	local points = {
		newp(0),
		newp(1),
		newp(10),
	}

	points[1]._tempo = Tempo(60)

	conv:compute(points)

	t:eq(points[1].absoluteTime, 0)
	t:eq(points[2].absoluteTime, 4)
	t:eq(points[3].absoluteTime, 40)
end

function test.no_zero_point(t)
	local conv = MeasureCompute()

	local points = {
		newp(-1),
		newp(1),
	}

	points[1]._tempo = Tempo(60)

	conv:compute(points)

	t:eq(points[1].absoluteTime, -4)
	t:eq(points[2].absoluteTime, 4)
end

function test.no_zero_point_right(t)
	local conv = MeasureCompute()

	local points = {
		newp(1),
	}

	points[1]._tempo = Tempo(60)

	conv:compute(points)

	t:eq(points[1].absoluteTime, 4)
end

function test.stop(t)
	local conv = MeasureCompute()

	local points = {
		newp(0),
		newp(0),
		newp(1),
	}

	points[1]._tempo = Tempo(120)  -- use fraction beat time here to test stops
	points[1]._stop = Stop(Fraction(1), false)  -- 1 beat

	conv:compute(points)

	t:eq(points[1].absoluteTime, 0)
	t:eq(points[2].absoluteTime, 0.5)
	t:eq(points[3].absoluteTime, 2.5)  -- default signature is 4
end

function test.signature(t)
	local conv = MeasureCompute()

	local points = {
		newp(0),
		newp(1),
		newp(2),
		newp(3),
		newp(4),
	}

	points[1]._tempo = Tempo(60)

	-- long mode
	points[2]._signature = Signature(Fraction(8))
	points[4]._signature = Signature(Fraction(2))

	conv:compute(points)

	t:eq(points[1].absoluteTime, 0)
	t:eq(points[2].absoluteTime, 4)
	t:eq(points[3].absoluteTime, 12)
	t:eq(points[4].absoluteTime, 20)
	t:eq(points[5].absoluteTime, 22)

	-- short mode
	points[3]._signature = Signature()
	points[5]._signature = Signature()

	conv:compute(points)

	t:eq(points[1].absoluteTime, 0)
	t:eq(points[2].absoluteTime, 4)
	t:eq(points[3].absoluteTime, 12)
	t:eq(points[4].absoluteTime, 16)
	t:eq(points[5].absoluteTime, 18)
end

return test
