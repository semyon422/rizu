local VisualColumns = require("chart.model.visual.VisualColumns")
local Visual = require("chart.model.visual.Visual")
local Point = require("chart.model.tp.Point")

local test = {}

function test.basic(t)
	local visual = Visual()
	local vc = VisualColumns(visual)
	local p = Point(0)

	local vp11 = vc:getPoint(p, "key1")
	local vp12 = vc:getPoint(p, "key1")

	local vp21 = vc:getPoint(p, "key2")
	local vp22 = vc:getPoint(p, "key2")
	local vp23 = vc:getPoint(p, "key2")

	t:eq(vp11, vp21)
	t:eq(vp12, vp22)

	t:ne(vp21, vp22)
	t:ne(vp22, vp23)
end

return test
