local InputModeMultiSelect = require("ui.views.form.InputModeMultiSelect")

local test = {}

---@param t testing.T
function test.normalizes_input_modes(t)
	t:eq(InputModeMultiSelect.normalize("14K"), "14K")
	t:eq(InputModeMultiSelect.normalize("14K2S"), "14key2scratch")
	t:eq(InputModeMultiSelect.normalize("5K1P1S"), "5key1pedal1scratch")
	t:eq(InputModeMultiSelect.normalize("88key"), "88key")
	t:eq(InputModeMultiSelect.normalize("not a mode"), nil)
end

---@param t testing.T
function test.set_values_normalizes_and_deduplicates(t)
	local control
	control = {
		values = {},
		normalize = InputModeMultiSelect.normalize,
		on_change = function(values)
			control.notified = values
		end,
	}

	InputModeMultiSelect.setValues(control, {"14K2S", "7K", "14key2scratch"}, true)
	t:tdeq(control.values, {"14key2scratch", "7K"})
	t:eq(control.notified, control.values)
end

---@param t testing.T
function test.visible_values_append_custom_modes_and_report_overflow(t)
	local control = {
		values = {"11K", "14key2scratch", "88K"},
		width = 390,
		font = {getWidth = function(_, text) return #text * 8 end},
		getLabel = InputModeMultiSelect.getLabel,
	}

	local values, overflowed = InputModeMultiSelect.getVisibleValues(control)
	t:tdeq(values, {"4K", "7K", "10K", "14K", "11K"})
	t:eq(overflowed, true)
end

---@param t testing.T
function test.visible_values_reserve_space_for_add_button(t)
	local control = {
		values = {},
		width = 255,
		font = {getWidth = function(_, text) return #text * 8 end},
		getLabel = InputModeMultiSelect.getLabel,
	}

	local values, overflowed = InputModeMultiSelect.getVisibleValues(control)
	t:tdeq(values, {"4K", "7K"})
	t:eq(overflowed, true)
end

return test
