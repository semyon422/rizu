local Inputs = require("gui.input.Inputs")
local Keybind = require("ui.views.form.Keybind")
local Screen = require("gui.Screen")
local View = require("gui.View")

local test = {}

---@param t testing.T
function test.activation_requests_keyboard_focus(t)
	local keybind = View()
	local screen = Screen()
	local inputs = Inputs()
	screen:acceptInputs(inputs)
	screen.root:add(keybind)
	screen:resize(100, 100)

	local activated = Keybind.activate(keybind, {
		control_pressed = false,
		shift_pressed = false,
		alt_pressed = false,
		super_pressed = false,
	})

	t:eq(activated, true)
	t:eq(inputs.keyboard_focus, keybind)
end

---@param t testing.T
function test.binds_one_key_with_modifiers(t)
	local changed ---@type rizu.config.KeyBinding?
	local keybind = View()
	keybind.binding = {key = "o"}
	keybind.on_change = function(binding) changed = binding end
	keybind.getBinding = Keybind.getBinding
	keybind.setBinding = Keybind.setBinding
	keybind.onKeyDown = Keybind.onKeyDown
	keybind.onKeyUp = Keybind.onKeyUp
	keybind.onFocusLost = Keybind.onFocusLost
	keybind.focused = true

	local screen = Screen()
	local inputs = Inputs()
	screen:acceptInputs(inputs)
	screen.root:add(keybind)
	screen:resize(100, 100)
	inputs:setKeyboardFocus(keybind, {control = false, shift = false, alt = false, super = false})

	local handled = keybind:onKeyDown({
		key = "+",
		control_pressed = true,
		shift_pressed = true,
		alt_pressed = false,
		super_pressed = false,
		is_repeated = false,
	})

	t:eq(handled, true)
	t:eq(changed, nil)
	t:tdeq(keybind.preview_binding, {
		key = "+",
		control = true,
		shift = true,
		alt = false,
		super = false,
	})

	handled = keybind:onKeyUp({
		key = "+",
		control_pressed = true,
		shift_pressed = true,
		alt_pressed = false,
		super_pressed = false,
	})
	t:eq(handled, true)
	t:tdeq(changed, {
		key = "+",
		control = true,
		shift = true,
		alt = false,
		super = false,
	})
	t:eq(inputs.keyboard_focus, nil)
end

---@param t testing.T
function test.modifier_key_does_not_finish_binding(t)
	local keybind = {
		focused = true,
		binding = {key = "o"},
	}
	local handled = Keybind.onKeyDown(keybind, {
		key = "lctrl",
		control_pressed = true,
		shift_pressed = false,
		alt_pressed = false,
		super_pressed = false,
		is_repeated = false,
	})

	t:eq(handled, true)
	t:eq(keybind.binding.key, "o")
	t:tdeq(keybind.preview_binding, {
		key = "",
		control = true,
		shift = false,
		alt = false,
		super = false,
	})
end

return test
