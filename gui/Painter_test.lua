local Painter = require("gui.Painter")

local test = {}

---@param t testing.T
function test.begin_and_color_multiply_inherited_and_color_opacity(t)
	Painter.begin(0.5)
	Painter.setColorTable({0.2, 0.3, 0.4, 0.6})

	local r, g, b, a = love.graphics.getColor()
	t:aeq(r, 0.2, 1e-6)
	t:aeq(g, 0.3, 1e-6)
	t:aeq(b, 0.4, 1e-6)
	t:aeq(a, 0.3, 1e-6)
end

---@param t testing.T
function test.local_opacity_preserves_inherited_and_color_opacity(t)
	Painter.begin(0.5)
	Painter.setColorRgb(0.2, 0.3, 0.4, 0.8)
	Painter.setOpacity(0.25)

	local _, _, _, a = love.graphics.getColor()
	t:aeq(a, 0.1, 1e-6)
end

---@param t testing.T
function test.begin_resets_all_local_color_state(t)
	Painter.begin(0.2)
	Painter.setColorRgb(0.1, 0.2, 0.3, 0.4)
	Painter.setOpacity(0.5)
	Painter.begin(0.75)

	local r, g, b, a = love.graphics.getColor()
	t:eq(r, 1)
	t:eq(g, 1)
	t:eq(b, 1)
	t:aeq(a, 0.75, 1e-9)
end

return test
