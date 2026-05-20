local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local Velocity = require("chart.model.visual.Velocity")
local Visual = require("chart.model.visual.Visual")

local test = {}

function test.basic(t)
	local layer = AbsoluteLayer()
	local visual = Visual()
	layer.visuals.main = visual

	local p_0 = layer:getPoint(0)
	local vp_0 = visual:newPoint(p_0)
	vp_0._velocity = Velocity(2)

	local p_1 = layer:getPoint(2)
	local vp_1 = visual:newPoint(p_1)

	layer:compute()

	t:eq(vp_1.visualTime, 4)
	t:eq(vp_1.point.absoluteTime, 2)
end

return test
