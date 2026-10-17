local Checkbox = require("ui.views.form.Checkbox")

local test = {}

---@param t testing.T
function test.activation_toggles_checkbox(t)
	local checkbox = {
		checked = false,
		setChecked = Checkbox.setChecked,
	}
	local notified
	checkbox.on_change = function(checked)
		notified = checked
	end

	t:eq(Checkbox.activate(checkbox), true)
	t:eq(checkbox.checked, true)
	t:eq(notified, true)
end

return test
