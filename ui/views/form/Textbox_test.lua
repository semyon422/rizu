local Inputs = require("gui.input.Inputs")
local Screen = require("gui.Screen")
local Textbox = require("ui.views.form.Textbox")
local View = require("gui.View")

local test = {}

---@param t testing.T
function test.activation_requests_keyboard_focus(t)
	local textbox = View()
	local screen = Screen()
	local inputs = Inputs()
	screen:acceptInputs(inputs)
	screen.root:add(textbox)
	screen:resize(100, 100)

	local activated = Textbox.activate(textbox, {
		control_pressed = false,
		shift_pressed = false,
		alt_pressed = false,
		super_pressed = false,
	})

	t:eq(activated, true)
	t:eq(inputs.keyboard_focus, textbox)
end

---@param t testing.T
function test.commits_changes_on_focus_lost(t)
	local committed ---@type string?
	local textbox = {
		model = {
			getText = function() return "changed" end,
		},
		committed_text = "initial",
		on_change = function(text) committed = text end,
		notifyChange = Textbox.notifyChange,
	}

	Textbox.onFocusLost(textbox, {})
	t:eq(committed, "changed")
	t:eq(textbox.committed_text, "changed")

	committed = nil
	Textbox.onFocusLost(textbox, {})
	t:eq(committed, nil)
end

---@param t testing.T
function test.escape_clears_keyboard_focus(t)
	local textbox = View()
	textbox.onKeyDown = Textbox.onKeyDown
	textbox.focused = true
	local screen = Screen()
	local inputs = Inputs()
	screen:acceptInputs(inputs)
	screen.root:add(textbox)
	screen:resize(100, 100)
	inputs:setKeyboardFocus(textbox, {control = false, shift = false, alt = false, super = false})

	local handled = textbox:onKeyDown({
		key = "escape",
		control_pressed = false,
		shift_pressed = false,
		alt_pressed = false,
		super_pressed = false,
	})

	t:eq(handled, true)
	t:eq(inputs.keyboard_focus, nil)
	t:eq(textbox.focused, false)
end

return test
