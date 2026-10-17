local Dropdown = require("ui.views.form.Dropdown")

local test = {}

---@param t testing.T
function test.standalone_dropdown_closes_without_form(t)
	local items_closed = false
	local dropdown = {
		opened = true,
		form = nil,
		items = {
			close = function()
				items_closed = true
			end,
		},
		onClosed = function() end,
	}

	t:eq(Dropdown.close(dropdown), true)
	t:eq(dropdown.opened, false)
	t:eq(dropdown.items, nil)
	t:eq(items_closed, true)
end

---@param t testing.T
function test.dropdown_deactivates_provided_form(t)
	local deactivated
	local dropdown = {
		opened = true,
		form = {
			deactivateDropdown = function(_, value)
				deactivated = value
			end,
		},
		onClosed = function() end,
	}

	Dropdown.close(dropdown)
	t:eq(deactivated, dropdown)
end

return test
