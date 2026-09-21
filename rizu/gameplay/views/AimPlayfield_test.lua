local AimPlayfield = require("rizu.gameplay.views.AimPlayfield")
local test = {}

---@param t testing.T
function test.pointer_mapping_round_trips_across_transformed_viewports(t)
	for _, size in ipairs({{640, 480}, {1280, 720}, {900, 1200}}) do
		local view = AimPlayfield(nil)
		-- A non-axis-aligned affine transform, equivalent to a translated,
		-- rotated, scaled, and skewed love.Transform.
		local transform = {a = 1.117, b = 0.355, c = -0.195, d = 0.743, x = 15, y = 20}
		function transform:transformPoint(x, y)
			return self.a * x + self.c * y + self.x, self.b * x + self.d * y + self.y
		end
		function transform:inverseTransformPoint(x, y)
			local determinant = self.a * self.d - self.b * self.c
			x, y = x - self.x, y - self.y
			return (self.d * x - self.c * y) / determinant, (-self.b * x + self.a * y) / determinant
		end
		local scale, ox, oy = view:getField(size[1], size[2])
		local x, y = transform:transformPoint(ox + 123 * scale, oy + 321 * scale)
		x, y = view:toChart(x, y, size[1], size[2], transform)
		t:aeq(x, 123, 1e-9)
		t:aeq(y, 321, 1e-9)
	end
end

return test
