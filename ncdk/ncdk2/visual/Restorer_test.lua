local Visual = require("ncdk2.visual.Visual")
local VisualPoint = require("ncdk2.visual.VisualPoint")
local Point = require("ncdk2.tp.Point")
local Velocity = require("ncdk2.visual.Velocity")
local Expand = require("ncdk2.visual.Expand")
local Restorer = require("ncdk2.visual.Restorer")

local test = {}

function test.basic_velocity(t)
	local vp0 = VisualPoint(Point(0))
	vp0.visualTime = 0

	local vp1 = VisualPoint(Point(1))
	vp1.visualTime = 2

	Restorer:restore({vp0, vp1})

	t:eq(vp0._velocity.currentSpeed, 2)
	t:assert(not vp1._velocity)
end

function test.basic_expand(t)
	local vp0 = VisualPoint(Point(0))
	vp0.visualTime = 0

	local vp1 = VisualPoint(Point(0))
	vp1.visualTime = 2

	Restorer:restore({vp0, vp1})

	t:eq(vp0._expand.duration, 2)
end

function test.velocity_single(t)
	local vp0 = VisualPoint(Point(0))
	vp0.visualTime = 0 -- <- x2

	local vp1 = VisualPoint(Point(1))
	vp1.visualTime = 2

	local vp2 = VisualPoint(Point(2))
	vp2.visualTime = 4

	Restorer:restore({vp0, vp1, vp2})

	t:eq(vp0._velocity.currentSpeed, 2)
	t:assert(not vp1._velocity)
	t:assert(not vp2._velocity)
end

function test.velocity_middle(t)
	local vp0 = VisualPoint(Point(0))
	vp0.visualTime = 0 -- <- x1

	local vp1 = VisualPoint(Point(1))
	vp1.visualTime = 1 -- <- x2

	local vp2 = VisualPoint(Point(2))
	vp2.visualTime = 3

	Restorer:restore({vp0, vp1, vp2})

	t:eq(vp0._velocity.currentSpeed, 1)
	t:eq(vp1._velocity.currentSpeed, 2)
	t:assert(not vp2._velocity)
end

return test
