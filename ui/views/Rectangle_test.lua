local Rectangle = require("ui.views.Rectangle")

local test = {}

---@param t testing.T
function test.stores_color(t)
	local color = {0.1, 0.2, 0.3, 0.4}
	local rectangle = Rectangle(color)

	t:eq(rectangle.color, color)
end

return test
