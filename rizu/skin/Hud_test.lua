local Hud = require("rizu.skin.Hud")
local View = require("rizu.skin.View")

local test = {}

---@param t testing.T
function test.draws_children_in_the_renderer_supplied_native_viewport(t)
	local hud = Hud({width = 640, height = 480})
	local point = View({
		anchor = "bottom_right",
		origin = "bottom_right",
		width = 10,
		height = 10,
	})
	local received_width, received_height, received_transform
	function point:drawAtAnchors(width, height, transform)
		received_width, received_height, received_transform = width, height, transform
	end
	hud:add(point)
	local parent_transform = love.math.newTransform()
	parent_transform:translate(5, 7)
	hud:draw(640, 480, parent_transform)
	t:eq(received_width, 640)
	t:eq(received_height, 480)
	local x, y = received_transform:transformPoint(10, 10)
	t:eq(x, 15)
	t:eq(y, 17)
end

return test
