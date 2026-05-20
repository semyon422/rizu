local FullEventScroller = require("chart.model.visual.FullEventScroller")
local VisualPoint = require("chart.model.visual.VisualPoint")
local Point = require("chart.model.tp.Point")

---@param t number
local function new_vp(t)
	local p = Point(t)
	local vp = VisualPoint(p)
	vp.visualTime = t
	return vp
end

local test = {}

---@param t testing.T
function test.end_po2(t)
	local fes = FullEventScroller()

	fes:generate({new_vp(0), new_vp(1), new_vp(2)})
	t:eq(fes.end_po2, 1)

	fes:generate({new_vp(0), new_vp(1), new_vp(2.1)})
	t:eq(fes.end_po2, 2)

	fes:generate({new_vp(0), new_vp(1), new_vp(1.9)})
	t:eq(fes.end_po2, 1)
end

---@param t testing.T
function test.low_range(t)
	local fes = FullEventScroller()

	---@type {[number]: number}
	local events = {}
	local function f(vp, action)
		events[vp.point.absoluteTime] = action
	end

	fes:generate({new_vp(0), new_vp(1), new_vp(2)})

	fes:scroll(-10, f)
	t:tdeq(events, {})

	-- first note is visible because min range is 0.5s
	fes:scale(0.001, f)
	fes:scroll(-0.2, f)
	t:tdeq(events, {[0] = 1})

	fes:scale(1, f)
	t:tdeq(events, {[0] = 1})

	-- all notes are visible because scale selects scroller for end_po2 that uses inf range
	fes:scale(1.001, f)
	t:tdeq(events, {[0] = 1, [1] = 1, [2] = 1})
end

return test
