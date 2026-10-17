local ActionMap = require("gui.input.ActionMap")

local test = {}

---@param t testing.T
function test.matches_exact_modifiers(t)
	local actions = ActionMap()
	local binding = {key = "o", control = true}

	t:eq(actions:bindingMatchesModifiers(binding, {
		control = true, shift = false, alt = false, super = false,
	}), true)
	t:eq(actions:bindingMatchesModifiers(binding, {
		control = true, shift = true, alt = false, super = false,
	}), false)
end

---@param t testing.T
function test.bindings_are_copied_and_can_be_displayed(t)
	local actions = ActionMap()
	local binding = {key = ";", shift = true}
	actions:defineAction("ui.command_palette", {binding})
	binding.key = "x"

	t:eq(actions:getBindingLabel("ui.command_palette"), "Shift+;")
	local bindings = actions:getBindings("ui.command_palette")
	bindings[1].key = "y"
	t:eq(actions:getBindingLabel("ui.command_palette"), "Shift+;")
end

return test
