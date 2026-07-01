local SelectionWindowSync = require("rizu.select.services.SelectionWindowSync")

local test = {}

---@param t testing.T
function test.update_enables_select_vsync(t)
	local enabled
	local windowModel = {
		setVsyncOnSelect = function(_, value)
			enabled = value
		end,
	}

	SelectionWindowSync(windowModel):update()

	t:eq(enabled, true)
end

return test
