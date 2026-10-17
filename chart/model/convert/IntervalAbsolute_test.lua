local IntervalAbsolute = require("chart.model.convert.IntervalAbsolute")
local IntervalLayer = require("chart.model.layers.IntervalLayer")
local IntervalPoint = require("chart.model.tp.IntervalPoint")
local Vertex = require("chart.model.to.Interval")
local Measure = require("chart.model.to.Measure")
local Fraction = require("chart.core.Fraction")

local test = {}

function test.basic(t)
	local conv = IntervalAbsolute()

	local layer = IntervalLayer()

	local p0 = layer:getPoint(Fraction(0))
	local p1 = layer:getPoint(Fraction(1, 4))
	local p2 = layer:getPoint(Fraction(5, 4))
	local p3 = layer:getPoint(Fraction(2))

	p0._vertex = Vertex(0)
	p1._vertex = Vertex(0.25)
	p2._vertex = Vertex(1.25)

	layer:compute()

	conv:convert(layer)

	t:eq(p0:getBeatModulo(), 0)
	t:eq(p1:getBeatModulo(), 0.25)
	t:eq(p2:getBeatModulo(), 0.25)
	t:eq(p3:getBeatModulo(), 0)
end

function test.single_measure1(t)
	local conv = IntervalAbsolute()

	local layer = IntervalLayer()

	local p0 = layer:getPoint(Fraction(0))
	local p1 = layer:getPoint(Fraction(1))
	local p15 = layer:getPoint(Fraction(3, 2))
	local p2 = layer:getPoint(Fraction(2))
	local p3 = layer:getPoint(Fraction(3))

	p1._vertex = Vertex(1)
	p2._vertex = Vertex(2)

	p15._measure = Measure(Fraction(1, 2))

	layer:compute()

	conv:convert(layer)

	t:eq(p0:getBeatModulo(), 0.5)
	t:eq(p1:getBeatModulo(), 0.5)
	t:eq(p15:getBeatModulo(), 0)
	t:eq(p2:getBeatModulo(), 0.5)
	t:eq(p3:getBeatModulo(), 0.5)
end

function test.single_measure2(t)
	local conv = IntervalAbsolute()

	local layer = IntervalLayer()

	local p0 = layer:getPoint(Fraction(0))
	local p1 = layer:getPoint(Fraction(1, 4))
	local p15 = layer:getPoint(Fraction(3, 2))
	local p2 = layer:getPoint(Fraction(11, 4))
	local p3 = layer:getPoint(Fraction(3))

	p1._vertex = Vertex(0.25)
	p2._vertex = Vertex(2.75)

	p15._measure = Measure(Fraction(1, 2))

	layer:compute()

	conv:convert(layer)

	t:eq(p0:getBeatModulo(), 0.5)
	t:eq(p1:getBeatModulo(), 0.75)
	t:eq(p15:getBeatModulo(), 0)
	t:eq(p2:getBeatModulo(), 0.25)
	t:eq(p3:getBeatModulo(), 0.5)
end

function test.measure_on_vertex(t)
	local conv = IntervalAbsolute()

	local layer = IntervalLayer()

	local p0 = layer:getPoint(Fraction(0))
	local p05 = layer:getPoint(Fraction(1, 2))
	local p2 = layer:getPoint(Fraction(2))

	p05._vertex = Vertex(0.5)
	p2._vertex = Vertex(2)

	p05._measure = Measure(Fraction(1, 4))

	layer:compute()

	conv:convert(layer)

	t:eq(p0:getBeatModulo(), 0.25)
	t:eq(p05:getBeatModulo(), 0.75)
	t:eq(p2:getBeatModulo(), 0.25)
end

---@param t testing.T
function test.invalid_fraction_time_errors(t)
	local conv = IntervalAbsolute()
	local fraction_mt = getmetatable(Fraction(0))

	local p = IntervalPoint(setmetatable({2220394914790230.75, 1}, fraction_mt))
	p._measure = Measure(Fraction(0))
	p.measure = p._measure
	p.absoluteTime = 1

	t:eq(t:has_error(function()
		conv:convertPoints({p})
	end), "invalid numerator: 2220394914790230.75")
end

return test
