local Form = require("ui.views.form.Form")
local FormControl = require("ui.views.form.FormControl")
local Inputs = require("gui.input.Inputs")
local Screen = require("gui.Screen")
local ScrollView = require("gui.ScrollView")
local View = require("gui.View")

local test = {}

---@param t testing.T
function test.rows_are_added_to_internal_flow(t)
	local form = Form({direction = "column", gap = 5})
	local first = View():setSize(20, 10)
	local second = View():setSize(30, 15)

	form:add(first)
	form:add(second)
	form:fitContent()

	t:eq(first.parent, form.rows)
	t:eq(second.parent, form.rows)
	t:eq(form.offset_max[1] - form.offset_min[1], 30)
	t:eq(form.offset_max[2] - form.offset_min[2], 30)
end

---@param t testing.T
function test.keyboard_movement_skips_non_controls_and_wraps(t)
	local form = Form()
	form:add(View())
	form:add(FormControl())
	form:add(View())
	form:add(FormControl())

	form:onKeyDown({key = "down"})
	t:eq(form.selected_index, 2)
	form:onKeyDown({key = "down"})
	t:eq(form.selected_index, 4)
	form:onKeyDown({key = "down"})
	t:eq(form.selected_index, 2)
	form:onKeyDown({key = "up"})
	t:eq(form.selected_index, 4)
end

---@param t testing.T
function test.selection_tracks_selected_control(t)
	local form = Form({direction = "column"})
	form:add(FormControl():setSize(100, 20))
	form:add(FormControl():setSize(80, 30))
	form:fitContent()
	form:anchorFixed(0, 0, 100, 50)
	form:relayout()

	form:moveSelection(1)
	form:updateSelection()
	t:eq(form.selection.visible, true)
	t:eq(form.selection.offset_y, 0)
	t:eq(form.selection.offset_max[1] - form.selection.offset_min[1], 100)

	form:moveSelection(1)
	form:updateSelection()
	t:eq(form.selection.offset_min[2], 0)
	t:eq(form.selection.offset_max[1] - form.selection.offset_min[1], 80)
	t:eq(form.selection.offset_y, 0)
	form.selection:finishTransforms()
	t:eq(form.selection.offset_y, 20)
end

---@param t testing.T
function test.keyboard_navigation_starts_at_visible_control(t)
	local form = Form({direction = "column"})
	for _ = 1, 5 do
		form:add(FormControl():setSize(100, 30))
	end
	form:fitContent()

	local scroll_view = ScrollView(form)
	scroll_view:anchorFixed(0, 0, 100, 50)
	local screen = Screen()
	screen.root:add(scroll_view)
	screen:resize(100, 50)
	scroll_view:scrollTo(60, true)

	form:moveSelection(1)

	t:eq(form.selected_index, 3)
	t:eq(scroll_view.scroll_target, 60)
end

---@param t testing.T
function test.keyboard_movement_centers_control_outside_scroll_view(t)
	local form = Form({direction = "column"})
	form:add(FormControl():setSize(100, 30))
	form:add(FormControl():setSize(100, 30))
	form:add(FormControl():setSize(100, 30))
	form:fitContent()

	local scroll_view = ScrollView(form)
	scroll_view:anchorFixed(0, 0, 100, 50)
	local screen = Screen()
	screen.root:add(scroll_view)
	screen:resize(100, 50)

	form:moveSelection(1)
	t:eq(form.selected_index, 1)
	t:eq(scroll_view.scroll_target, 0)
	form:moveSelection(1)
	t:eq(scroll_view.scroll_target, 20)
end

---@param t testing.T
function test.selection_follows_control_when_rows_are_inserted_and_removed(t)
	local form = Form()
	local first = form:add(FormControl())
	local second = form:add(FormControl())
	form:moveSelection(1)

	form:insert(1, View())
	t:eq(form.selected_control, first)
	t:eq(form.selected_index, 2)

	form:remove(first)
	t:eq(form.selected_control, second)
	t:eq(form.selected_index, 2)

	form:remove(second)
	t:eq(form.selected_control, nil)
	t:eq(form.selected_index, nil)
end

---@param t testing.T
function test.removing_last_control_selects_previous_control(t)
	local form = Form()
	local first = form:add(FormControl())
	local second = form:add(FormControl())
	form:moveSelection(-1)

	form:remove(second)
	t:eq(form.selected_control, first)
	t:eq(form.selected_index, 1)
end

---@param t testing.T
function test.mouse_input_clears_keyboard_selection(t)
	local form = Form()
	local control = form:add(FormControl())
	form:selectControl(control)

	control:onMouseDown({button = 1})

	t:eq(form.selected_control, nil)
	t:eq(form.selected_index, nil)
	t:eq(form.selection.visible, false)
end

---@param t testing.T
function test.keyboard_movement_skips_disabled_controls(t)
	local form = Form()
	local disabled = form:add(FormControl())
	disabled:setEnabled(false)
	local enabled = form:add(FormControl())

	form:moveSelection(1)
	t:eq(form.selected_control, enabled)
end

---@param t testing.T
function test.keyboard_movement_clears_keyboard_focus(t)
	local form = Form()
	local first = form:add(FormControl())
	local second = form:add(FormControl())
	local screen = Screen()
	local inputs = Inputs()
	screen:acceptInputs(inputs)
	screen.root:add(form)
	screen:resize(100, 100)
	form:selectControl(first)
	inputs:setKeyboardFocus(first, {control = false, shift = false, alt = false, super = false})

	form:onKeyDown({
		key = "down",
		control_pressed = false,
		shift_pressed = false,
		alt_pressed = false,
		super_pressed = false,
	})

	t:eq(form.selected_control, second)
	t:eq(inputs.keyboard_focus, nil)
end

---@param t testing.T
function test.keyboard_movement_is_ignored_during_drag(t)
	local form = Form()
	local control = form:add(FormControl())
	local screen = Screen()
	local inputs = Inputs()
	screen:acceptInputs(inputs)
	screen.root:add(form)
	screen:resize(100, 100)
	inputs.pointer_gesture = {dragging = true}

	local handled = form:onKeyDown({key = "down"})

	t:eq(handled, false)
	t:eq(form.selected_control, nil)
	t:eq(control.parent, form.rows)
end

---@param t testing.T
function test.keyboard_movement_without_controls_is_not_handled(t)
	local form = Form()
	form:add(View())

	t:eq(form:onKeyDown({key = "down"}), false)
	t:eq(form.selected_index, nil)
end

---@param t testing.T
function test.direct_child_overlay_can_remove_itself(t)
	local form = Form()
	local overlay = form:addOverlay(View())

	overlay.parent:remove(overlay)

	t:eq(overlay.parent, nil)
	t:eq(#form.children, 2)
end

---@param t testing.T
function test.update_repairs_selection_when_selected_control_is_disabled(t)
	local form = Form()
	local first = form:add(FormControl())
	local second = form:add(FormControl())
	form:selectControl(first)
	first:setEnabled(false)

	form:update(0)

	t:eq(form.selected_control, second)
end

---@param t testing.T
function test.update_closes_disabled_active_dropdown(t)
	local form = Form()
	local closed = false
	local dropdown = form:add(FormControl())
	function dropdown:close()
		closed = true
		form:deactivateDropdown(self)
		return true
	end
	form:activateDropdown(dropdown)
	dropdown:setEnabled(false)

	form:update(0)

	t:eq(closed, true)
	t:eq(form.active_dropdown, nil)
end

---@param t testing.T
function test.activating_dropdown_closes_previous(t)
	local form = Form()
	local first_closed = false
	local first = View()
	function first:close()
		first_closed = true
		form:deactivateDropdown(self)
		return true
	end
	local second = View()

	form:activateDropdown(first)
	form:activateDropdown(second)

	t:eq(first_closed, true)
	t:eq(form.active_dropdown, second)
end

return test
