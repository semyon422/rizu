local SliderPath = require("chart.format.osu.SliderPath")

local test = {}

---@param t testing.T
function test.linear_trim_extension_and_distance_sampling(t)
	local p = SliderPath("L", {{0, 0}, {100, 0}, {100, 100}}, 150)
	t:tdeq({p:position(1)}, {100, 50})
	t:tdeq({p:position(0.5)}, {75, 0})
	local extended = SliderPath("L", {{0, 0}, {100, 0}}, 200)
	t:tdeq({extended:position(1)}, {200, 0})
	t:tdeq({extended:position(-1)}, {0, 0})
end

---@param t testing.T
function test.bezier_segments_and_curvature(t)
	local split = SliderPath("B", {{0, 0}, {100, 0}, {100, 0}, {100, 100}}, 200)
	t:tdeq({split:position(0.5)}, {100, 0})
	t:tdeq({split:position(1)}, {100, 100})
	-- A symmetric quadratic has its apex at (50, 50).
	local p = SliderPath("B", {{0, 0}, {50, 100}, {100, 0}}, 147.894)
	local x, y = p:position(0.5)
	t:aeq(x, 50, 0.1)
	t:aeq(y, 50, 0.1)
	t:assert(#p.points > 3)
end

---@param t testing.T
function test.perfect_arc_directions_and_collinear_fallback(t)
	for _, sign in ipairs({-1, 1}) do
		local p = SliderPath("P", {{100, 0}, {0, sign * 100}, {-100, 0}}, math.pi * 100)
		local x, y = p:position(0.5)
		t:aeq(x, 0, 0.2)
		t:aeq(y, sign * 100, 0.2)
	end
	local line = SliderPath("P", {{0, 0}, {50, 0}, {100, 0}}, 100)
	t:tdeq({line:position(0.5)}, {50, 0})
end

---@param t testing.T
function test.catmull_and_degenerate_paths(t)
	local p = SliderPath("C", {{0, 0}, {100, 0}}, 100)
	local x, y = p:position(0.5)
	t:aeq(x, 50, 1e-6)
	t:eq(y, 0)
	local point = SliderPath("B", {{10, 20}, {10, 20}}, 100)
	t:tdeq({point:position(1)}, {10, 20})
	t:eq(point.length, 0)
	local zero = SliderPath("L", {{10, 20}, {30, 40}}, 0)
	t:tdeq({zero:position(1)}, {10, 20})
end

---@param t testing.T
function test.invalid_geometry_fails_instead_of_degrading(t)
	t:has_error(function() SliderPath("L", {{0 / 0, 0}}, 1) end)
	t:has_error(function() SliderPath("X", {{0, 0}}, 1) end)
	t:has_error(function() SliderPath("L", {{0, 0}}, -1) end)
	local points = {}
	for i = 1, 1025 do points[i] = {i, 0} end
	t:has_error(function() SliderPath("B", points, 100) end)
end

return test
