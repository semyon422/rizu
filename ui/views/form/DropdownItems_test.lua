local DropdownItems = require("ui.views.form.DropdownItems")

local test = {}

---@param t testing.T
function test.keyboard_focus_wraps_and_selects_displayed_option(t)
	local selected_value
	local items = {
		options = {"a", "b", "c"},
		selected_index = 2,
		focused_display_index = 1,
		row_height = 40,
		getDisplayOption = DropdownItems.getDisplayOption,
		focusDisplayIndex = function(self, index)
			self.focused_display_index = ((index - 1) % #self.options) + 1
		end,
		on_select = function(value)
			selected_value = value
		end,
	}

	t:eq(DropdownItems.moveFocus(items, -1), true)
	t:eq(items.focused_display_index, 3)
	t:eq(DropdownItems.selectFocused(items), true)
	t:eq(selected_value, "c")
end

return test
