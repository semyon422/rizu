local Inputs = require("gui.input.Inputs")
local Resources = require("ui.Resources")
local Textbox = require("ui.views.Textbox")

local test = {}

local default_modifiers = {control = false, shift = false, alt = false, super = false}

---@param text string
---@return ui.views.Textbox
local function create_textbox(text)
	local get_font = Resources.getFont
	Resources.getFont = function()
		return {
			getHeight = function() return 24 end,
			getWidth = function(_, value) return #value * 12 end,
		}
	end
	local textbox = Textbox({text = text})
	Resources.getFont = get_font
	return textbox
end

---@param t testing.T
function test.ignores_keyboard_input_without_focus(t)
	local inputs = Inputs()
	local first = create_textbox("first")
	local last = create_textbox("last")
	inputs:processView(first)
	inputs:processView(last)

	inputs:receive({name = "textinput", "!"}, default_modifiers)
	inputs:receive({name = "keypressed", "backspace", nil, false}, default_modifiers)

	t:eq(first:getText(), "first")
	t:eq(last:getText(), "last")
end

---@param t testing.T
function test.accepts_keyboard_input_with_focus(t)
	local inputs = Inputs()
	local textbox = create_textbox("text")
	inputs:setKeyboardFocus(textbox, default_modifiers)

	inputs:receive({name = "textinput", "!"}, default_modifiers)
	inputs:receive({name = "keypressed", "backspace", nil, false}, default_modifiers)

	t:eq(textbox:getText(), "text")
end

return test
