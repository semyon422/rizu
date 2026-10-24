local EditorSlider = require("ui.views.editor.EditorSlider")

local test = {}

---@param t testing.T
function test.position_in_the_field_sets_a_stepped_value(t)
	local notified ---@type number?
	local slider = setmetatable({
		label_text = "X", width = 110, min = 0, max = 10, step = 2, value = 0,
		world_transform = {inverseTransformPoint = function(_, x, y) return x, y end},
		on_change = function(value) notified = value end,
	}, {__index = EditorSlider})
	local field_x = slider:getField() -- 44 + 8 gap: the field is 58 wide

	slider:setValueAt(field_x + 58 * 0.45, 0)
	t:eq(slider.value, 4)
	t:eq(notified, 4)
	slider:setValueAt(0, 0) -- on the label
	t:eq(slider.value, 0)
	slider:setValueAt(1000, 0)
	t:eq(slider.value, 10)
end

---@param name string
---@return gui.KeyDownEvent
local function key(name)
	return {key = name} --[[@as gui.KeyDownEvent]] ---@diagnostic disable-line: missing-fields
end

---@param t testing.T
function test.left_and_right_step_the_hovered_slider(t)
	local slider = setmetatable({min = 0, max = 1, step = 0.25, value = 0.5, mouse_over = true}, {__index = EditorSlider})
	t:eq(slider:onKeyDown(key("right")), true)
	t:eq(slider.value, 0.75)
	slider:onKeyDown(key("right"))
	slider:onKeyDown(key("right"))
	t:eq(slider.value, 1) -- clamped
	slider:onKeyDown(key("left"))
	t:eq(slider.value, 0.75)
	t:eq(slider:onKeyDown(key("up")), false)
	slider.mouse_over = false
	t:eq(slider:onKeyDown(key("left")), false)
	t:eq(slider.value, 0.75)
end

return test
