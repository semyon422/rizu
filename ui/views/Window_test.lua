local Window = require("ui.views.Window")

local test = {}

---@param t testing.T
function test.inactive_opacity_can_be_configured(t)
	local window = {
		inactive_opacity = nil,
		opacity_target = nil,
	}

	Window.setInactiveOpacity(window, 0.35)

	t:eq(window.inactive_opacity, 0.35)
	t:eq(window.opacity_target, nil)
end

---@param t testing.T
function test.dragging_header_moves_window(t)
	local calls = {}
	local window = {
		parent = nil,
		offset_x = 0,
		offset_y = 0,
		world_transform = {
			inverseTransformPoint = function(_, x, y) return x, y end,
		},
		setOffset = function(self, x, y)
			calls[#calls + 1] = {x, y}
		end,
	}

	Window.beginDrag(window, {press_x = 100, press_y = 100, x = 100, y = 100})
	Window.drag(window, {x = 135, y = 140})
	Window.endDrag(window)

	t:tdeq(calls, {{35, 40}})
	t:eq(window.drag_active, false)
end

return test
