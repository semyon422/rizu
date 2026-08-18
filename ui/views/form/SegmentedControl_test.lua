local SegmentedControl = require("ui.views.form.SegmentedControl")

local test = {}

---@param t testing.T
function test.keyboard_selection_wraps(t)
	local notified
	local control = {
		options = {"a", "b", "c"},
		value = "a",
		getSelectedIndex = SegmentedControl.getSelectedIndex,
		selectIndex = SegmentedControl.selectIndex,
		setValue = SegmentedControl.setValue,
		on_change = function(value)
			notified = value
		end,
	}

	t:eq(SegmentedControl.onFormKeyDown(control, {key = "left"}), true)
	t:eq(control.value, "c")
	t:eq(notified, "c")
	t:eq(SegmentedControl.onFormKeyDown(control, {key = "right"}), true)
	t:eq(control.value, "a")
	t:eq(SegmentedControl.onFormKeyDown(control, {key = "up"}), false)
end

---@param t testing.T
function test.invalid_value_selects_edge_with_keyboard(t)
	local control = {
		options = {"a", "b"},
		value = "missing",
		getSelectedIndex = SegmentedControl.getSelectedIndex,
		selectIndex = SegmentedControl.selectIndex,
		setValue = SegmentedControl.setValue,
	}

	t:eq(SegmentedControl.onFormKeyDown(control, {key = "right"}), true)
	t:eq(control.value, "a")
	control.value = "missing"
	t:eq(SegmentedControl.onFormKeyDown(control, {key = "left"}), true)
	t:eq(control.value, "b")
end

return test
