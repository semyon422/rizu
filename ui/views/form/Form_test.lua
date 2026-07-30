local Form = require("ui.views.form.Form")
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
