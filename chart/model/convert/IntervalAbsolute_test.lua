local IntervalAbsolute = require("chart.model.convert.IntervalAbsolute")
local IntervalLayer = require("chart.model.layers.IntervalLayer")
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

return test
