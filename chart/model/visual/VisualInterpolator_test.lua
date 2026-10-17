local VisualInterpolator = require("chart.model.visual.VisualInterpolator")
local VisualPoint = require("chart.model.visual.VisualPoint")
local Point = require("chart.model.tp.Point")

local test = {}

function test.absolute(t)
	local itp = VisualInterpolator()

	local points = {
		Point(0),
		Point(1),
	}

	local visualPoints = {
		VisualPoint(points[1]),
		VisualPoint(points[2]),
	}
	visualPoints[1].visualTime = 2
	visualPoints[1].monotonicVisualTime = 2

	visualPoints[2].visualTime = 4
	visualPoints[2].monotonicVisualTime = 4

	visualPoints[1].currentSpeed = 2

	local vp = VisualPoint(Point(0.5))

	local index = itp:interpolate(visualPoints, vp, "absolute")
	t:eq(index, 1)
	t:eq(vp.visualTime, 3)
	t:eq(vp.monotonicVisualTime, 3)

	vp.point.absoluteTime = -1
	index = itp:interpolate(visualPoints, vp, "absolute")
	t:eq(index, 1)
	t:eq(vp.visualTime, 0)
	t:eq(vp.monotonicVisualTime, 0)
end

function test.visual(t)
	local itp = VisualInterpolator()

	local points = {
		Point(0),
		Point(1),
	}

	local visualPoints = {
		VisualPoint(points[1]),
		VisualPoint(points[2]),
	}
	visualPoints[1].visualTime = 2
	visualPoints[1].monotonicVisualTime = 2

	visualPoints[2].visualTime = 4
	visualPoints[2].monotonicVisualTime = 4

	visualPoints[1].currentSpeed = 2

	local vp = VisualPoint(Point())
	vp.monotonicVisualTime = 3

	local index = itp:interpolate(visualPoints, vp, "visual")
	t:eq(index, 1)
	t:eq(vp.point.absoluteTime, 0.5)
	t:eq(vp.visualTime, 3)

	vp.monotonicVisualTime = 0
	index = itp:interpolate(visualPoints, vp, "visual")
	t:eq(index, 1)
	t:eq(vp.point.absoluteTime, -1)
	t:eq(vp.visualTime, 0)
end

function test.sections(t)
	local itp = VisualInterpolator()

	local visualPoints = {
		VisualPoint(Point(0)),
		VisualPoint(Point(0)),
	}
	visualPoints[2].section = 1

	for _, vp in ipairs(visualPoints) do
		vp.monotonicVisualTime = vp.point.absoluteTime
	end

	local vp = VisualPoint(Point(0))
	itp:interpolate(visualPoints, vp, "absolute")
	t:eq(vp.monotonicVisualTime, 0)
	t:eq(vp.visualTime, 0)
	t:eq(vp.section, 0)

	vp.section = 1
	itp:interpolate(visualPoints, vp, "visual")
	t:eq(vp.monotonicVisualTime, 0)
	t:eq(vp.visualTime, 0)
	t:eq(vp.section, 1)
end

function test.negative(t)
	--[[
---v1------------------v2----
							v3
		---------vp----------
	   v4
		---v5------------------v6---
	]]

	local itp = VisualInterpolator()

	local visualPoints = { -- always ordered by absolute time
		VisualPoint(Point(1)),
		VisualPoint(Point(6)),
		VisualPoint(Point(7)),
		VisualPoint(Point(12)),
		VisualPoint(Point(13)),
		VisualPoint(Point(18)),
	}

	visualPoints[1].visualTime = 1
	visualPoints[2].visualTime = 6
	visualPoints[3].visualTime = 7
	visualPoints[4].visualTime = 2
	visualPoints[5].visualTime = 3
	visualPoints[6].visualTime = 8

	visualPoints[3].currentSpeed = -1

	for _, vp in ipairs(visualPoints) do
		vp.monotonicVisualTime = vp.point.absoluteTime
	end

	local vp = VisualPoint(Point(9.5))
	local index = itp:interpolate(visualPoints, vp, "absolute")
	t:eq(index, 3)
	t:eq(vp.monotonicVisualTime, 9.5)
	t:eq(vp.visualTime, 4.5)

	index = itp:interpolate(visualPoints, vp, "visual")
	t:eq(index, 3)
	t:eq(vp.visualTime, 4.5)
	t:eq(vp.point.absoluteTime, 9.5)

	index = itp:interpolate(visualPoints, vp, "visual")
	t:eq(index, 3)
	t:eq(vp.visualTime, 4.5)
	t:eq(vp.point.absoluteTime, 9.5)

	index = itp:interpolate(visualPoints, vp, "visual")
	t:eq(index, 3)
	t:eq(vp.visualTime, 4.5)
	t:eq(vp.point.absoluteTime, 9.5)

	index = itp:interpolate(visualPoints, vp, "visual")
	t:eq(index, 3)
	t:eq(vp.visualTime, 4.5)
	t:eq(vp.point.absoluteTime, 9.5)
end

return test
