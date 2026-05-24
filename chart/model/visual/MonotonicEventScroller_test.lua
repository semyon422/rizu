local MonotonicEventScroller = require("chart.model.visual.MonotonicEventScroller")
local VisualPoint = require("chart.model.visual.VisualPoint")
local Point = require("chart.model.tp.Point")
local Visual = require("chart.model.visual.Visual")

---@param t number
local function new_vp(t)
	local p = Point(t)
	local vp = VisualPoint(p)
	vp.visualTime = t
	return vp
end

local test = {}

---@param t testing.T
local Velocity = require("chart.model.visual.Velocity")

function test.basic(t)
	local vis = Visual()
	vis.primaryTempo = 60
	vis.points = {
		new_vp(0),
		new_vp(1),
		new_vp(2),
		new_vp(3),
		new_vp(4),
	}
	for i, vp in ipairs(vis.points) do
		vp._velocity = Velocity(1)
	end
	vis:compute()

	local scroller = MonotonicEventScroller(vis)

	---@type {[number]: number}
	local events = {}
	local function f(vp, action)
		events[vp.point.absoluteTime] = action
	end

	-- range 1.0, visualTime 2.0 -> visible (1.0, 3.0]
	-- points at AT=2, 3 should be visible
	scroller:scale(1.0, f)
	scroller:scroll(2.0, f)

	t:eq(events[1], nil)
	t:eq(events[2], 1)
	t:eq(events[3], 1)
	t:eq(events[0], nil)
	t:eq(events[4], nil)

	-- move to 2.5. range (1.5, 3.5]
	-- points at 2, 3 stay visible
	scroller:scroll(2.5, f)
	-- visible (1.5, 3.5] -> 2, 3 are visible.
	t:eq(events[1], nil)
	t:eq(events[2], 1)
	t:eq(events[3], 1)
	t:eq(events[4], nil)

	-- increase range to 2.0. range (0.5, 4.5]
	-- visible 1, 2, 3, 4.
	scroller:scale(2.0, f)
	t:eq(events[1], 1)
	t:eq(events[4], 1)
	t:eq(events[0], nil)
end

return test
