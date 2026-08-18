local PopupContainer = require("ui.views.PopupContainer")
local Screen = require("gui.Screen")
local View = require("gui.View")

local test = {}

---@param t testing.T
function test.popup_can_remove_itself(t)
	local container = PopupContainer()
	local owner = {close = function() end}
	local popup = View()
	container:open(owner, popup)

	popup.parent:remove(popup)

	t:eq(popup.parent, nil)
	t:eq(container.popup, nil)
	t:eq(container.owner, nil)
	t:eq(container.handles_mouse_input, false)
end

---@param t testing.T
function test.opening_another_popup_closes_the_active_one(t)
	local container = PopupContainer()
	local closed = false
	local first = {
		close = function()
			closed = true
			container.popup.parent:remove(container.popup)
		end,
	}
	container:open(first, View())
	local second = {close = function() end}
	local second_popup = View()

	container:open(second, second_popup)

	t:eq(closed, true)
	t:eq(container.owner, second)
	t:eq(container.popup, second_popup)
end

---@param t testing.T
function test.popup_inherits_source_visual_scale(t)
	local screen = Screen()
	local scaled_parent = screen.root:add(View():anchorFixed(100, 50, 400, 400))
	scaled_parent:setScale(0.9, 0.9)
	local source = scaled_parent:add(View():anchorFixed(20, 30, 300, 65))
	local container = screen.root:add(PopupContainer())
	screen:resize(1920, 1080)
	local popup = View():setSize(300, 200)

	container:open({close = function() end}, popup, source)
	screen:flush()

	local source_x, source_y = source.world_transform:transformPoint(0, 0)
	local popup_x, popup_y = popup.world_transform:transformPoint(0, 0)
	t:aeq(popup_x, source_x, 1e-4)
	t:aeq(popup_y, source_y, 1e-4)
	t:aeq(popup.scale_x, 0.9, 1e-4)
	t:aeq(popup.scale_y, 0.9, 1e-4)
end

---@param t testing.T
function test.background_press_closes_popup(t)
	local container = PopupContainer()
	local closed = false
	local owner = {close = function() closed = true end}
	container:open(owner, View())

	t:eq(container:onMouseDown(), true)
	t:eq(closed, true)
end

return test
