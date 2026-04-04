local Projector = require("yi.globe.Projector")

local test = {}

---@param t testing.T
function test.rotate_point_around_y_axis(t)
	local x, y, z = Projector.rotatePoint(1, 0, 0, 0, math.pi / 2)

	t:assert(math.abs(x) < 0.000001, "rotated x should be near 0")
	t:eq(y, 0)
	t:assert(math.abs(z - 1) < 0.000001, "rotated z should be near 1")
end

---@param t testing.T
function test.project_point_scales_with_depth(t)
	local near_x, near_y = Projector.projectPoint(10, 5, 0, 100, 100, 200, 400)
	local far_x, far_y = Projector.projectPoint(10, 5, 100, 100, 100, 200, 400)

	t:eq(near_x, 105)
	t:eq(near_y, 102.5)
	t:eq(far_x, 104)
	t:eq(far_y, 102)
end

---@param t testing.T
function test.build_wireframe_returns_expected_segment_count(t)
	local segments = Projector.buildWireframe(100, 6, 8)

	t:eq(#segments, (6 - 1) * 8 + 6 * 8)
end

return test
