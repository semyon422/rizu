local KeyBindings = require("ui.helpers.KeyBindings")

local test = {}

---@param t testing.T
function test.format_and_parse_bindings(t)
	local bindings = {
		{key = "o", control = true, shift = true},
		{key = "return"},
	}

	t:eq(KeyBindings.format(bindings), "Ctrl+Shift+o, return")
	t:tdeq(KeyBindings.parse("Ctrl+Shift+o, return"), bindings)
end

---@param t testing.T
function test.empty_text_removes_bindings(t)
	t:tdeq(KeyBindings.parse(""), {})
end

---@param t testing.T
function test.rejects_multiple_keys(t)
	t:has_error(function()
		KeyBindings.parse("ctrl+o+p")
	end)
end

return test
