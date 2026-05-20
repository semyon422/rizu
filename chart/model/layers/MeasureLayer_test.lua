local MeasureLayer = require("chart.model.layers.MeasureLayer")
local Tempo = require("chart.model.to.Tempo")
local Velocity = require("chart.model.visual.Velocity")
local Visual = require("chart.model.visual.Visual")
local Fraction = require("chart.core.Fraction")

local test = {}

function test.basic(t)
	local layer = MeasureLayer()
	local visual = Visual()
	layer.visuals.main = visual

	local p_0 = layer:getPoint(Fraction(0))
	p_0._tempo = Tempo(120)
	local vp_0 = visual:newPoint(p_0)
	vp_0._velocity = Velocity(2)

	local p_1 = layer:getPoint(Fraction(1))
	local vp_1 = visual:newPoint(p_1)

	layer:compute()

	t:eq(vp_1.visualTime, 4)
	t:eq(vp_1.point.absoluteTime, 2)
end

return test
