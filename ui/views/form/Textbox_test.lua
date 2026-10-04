local ActionMap = require("gui.input.ActionMap")
local FocusLostEvent = require("gui.input.events.FocusLostEvent")
local Inputs = require("gui.input.Inputs")
local Screen = require("gui.Screen")
local Textbox = require("ui.views.form.Textbox")
local UiActions = require("ui.UiActions")
local View = require("gui.View")

local test = {}

local default_modifiers = {control = false, shift = false, alt = false, super = false}

---@param t testing.T
function test.activation_requests_keyboard_focus(t)
	local textbox = View()
	local screen = Screen()
	local inputs = Inputs()
	screen:acceptInputs(inputs)
	screen.root:add(textbox)
	screen:resize(100, 100)

	local activated = Textbox.activate(textbox --[[@as ui.views.form.Textbox]], {
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

	Textbox.onFocusLost(textbox, FocusLostEvent(default_modifiers))
	t:eq(committed, "changed")
	t:eq(textbox.committed_text, "changed")

	committed = nil
	Textbox.onFocusLost(textbox, FocusLostEvent(default_modifiers))
	t:eq(committed, nil)
end

---@param t testing.T
function test.secret_field_masks_display_but_preserves_actual_text(t)
	local textbox = {
		secret = true,
		model = {getText = function() return "secret" end},
		getText = Textbox.getText,
		getDisplayText = Textbox.getDisplayText,
	}
	t:eq(textbox:getText(), "secret")
	t:eq(textbox:getDisplayText("secret"), "••••••")
	t:eq(textbox:getDisplayText("päss"), "••••")
end

---@param t testing.T
function test.escape_clears_keyboard_focus(t)
	local textbox = View()
	textbox.onHandleInputs = Textbox.onHandleInputs
	textbox:setSize(100, 100)
	local screen = Screen()
	local inputs = Inputs()
	local actions = ActionMap()
	actions:defineAction(UiActions.cancel, {{key = "escape"}})
	inputs:setActionMap(actions)
	screen.root:add(textbox)
	screen:resize(100, 100)
	inputs:beginFrame(0, 0)
	screen:acceptInputs(inputs)
	inputs:setKeyboardFocus(textbox, {control = false, shift = false, alt = false, super = false})

	inputs:receive({name = "keypressed", "escape"}, {
		control = false, shift = false, alt = false, super = false,
	})
	textbox:onHandleInputs(inputs)

	t:eq(inputs:isActionJustPressed(UiActions.cancel), false)
	t:eq(inputs.keyboard_focus, nil)
	t:eq(textbox.focused, false)
end

return test
