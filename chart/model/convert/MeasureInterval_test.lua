local MeasureInterval = require("chart.model.convert.MeasureInterval")
local MeasureLayer = require("chart.model.layers.MeasureLayer")
local Tempo = require("chart.model.to.Tempo")
local Stop = require("chart.model.to.Stop")
local Fraction = require("chart.core.Fraction")

local test = {}

function test.basic(t)
	local conv = MeasureInterval()

	local layer = MeasureLayer()

	local p_0 = layer:getPoint(Fraction(0))
	p_0._tempo = Tempo(120)

	local p_1 = layer:getPoint(Fraction(1))

	layer:compute()

	conv:convert(layer)
	---@cast layer -ncdk2.MeasureLayer, +ncdk2.IntervalLayer

	---@type ncdk2.IntervalPoint[]
	local points = layer:getPointList()

	t:eq(#points, 2)
	t:eq(points[1].absoluteTime, 0)
	t:eq(points[2].absoluteTime, 2)
	t:eq(points[1]._vertex.offset, 0)
	t:eq(points[2]._vertex.offset, 2)
end

function test.stop(t)
	local conv = MeasureInterval()

	local layer = MeasureLayer()

	local p_0 = layer:getPoint(Fraction(0))
	p_0._tempo = Tempo(60)

	local p_1 = layer:getPoint(Fraction(1, 8)) -- 1/2
	local p_2 = layer:getPoint(Fraction(1, 8), true)
	p_1._stop = Stop(Fraction(1, 4))

	local p_3 = layer:getPoint(Fraction(1))

	layer:compute()

	conv:convert(layer)
	---@cast layer -ncdk2.MeasureLayer, +ncdk2.IntervalLayer

	---@type ncdk2.IntervalPoint[]
	local points = layer:getPointList()

	t:eq(#points, 4)

	t:eq(points[1].absoluteTime, 0)
	t:eq(points[2].absoluteTime, 0.5)
	t:eq(points[3].absoluteTime, 0.75)
	t:eq(points[4].absoluteTime, 4.25)

	t:eq(points[1].time, Fraction(0))
	t:eq(points[2].time, Fraction(1, 2))
	t:eq(points[3].time, Fraction(3, 2))
	t:eq(points[4].time, Fraction(5))
end

function test.fractions(t)
	local conv = MeasureInterval()

	local layer = MeasureLayer()

	local p_00 = layer:getPoint(Fraction(0))

	local p_0 = layer:getPoint(Fraction(1, 8))
	p_0._tempo = Tempo(120)

	local p_1 = layer:getPoint(Fraction(7, 8))
	p_1._tempo = Tempo(60)

	local p_2 = layer:getPoint(Fraction(1))

	layer:compute()

	conv:convert(layer)
	---@cast layer -ncdk2.MeasureLayer, +ncdk2.IntervalLayer

	---@type ncdk2.IntervalPoint[]
	local points = layer:getPointList()

	t:eq(#points, 4)

	t:eq(p_00.absoluteTime, 0)
	t:eq(p_0.absoluteTime, 0.25)
	t:eq(p_1.absoluteTime, 1.75)
	t:eq(p_2.absoluteTime, 2.25)

	t:eq(p_00.time, Fraction(0))
	t:eq(p_0.time, Fraction(1, 2))
	t:eq(p_1.time, Fraction(7, 2))
	t:eq(p_2.time, Fraction(4))

	t:eq(p_0._vertex.offset, 0.25)
	t:eq(p_1._vertex.offset, 1.75)
end

function test.single_point(t)
	local conv = MeasureInterval()

	local layer = MeasureLayer()

	local p_0 = layer:getPoint(Fraction(0))
	p_0._tempo = Tempo(120)

	layer:compute()

	conv:convert(layer)
	---@cast layer -ncdk2.MeasureLayer, +ncdk2.IntervalLayer

	---@type ncdk2.IntervalPoint[]
	local points = layer:getPointList()

	t:eq(#points, 2)
	t:eq(points[1].time, Fraction(0))
	t:eq(points[2].time, Fraction(1))
end

return test
