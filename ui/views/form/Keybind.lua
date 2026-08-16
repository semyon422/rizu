local FormControl = require("ui.views.form.FormControl")
local Colors = require("ui.Colors")
local KeyBindings = require("ui.helpers.KeyBindings")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.form.KeybindParams
---@field label string
---@field binding rizu.config.KeyBinding
---@field width number?
---@field binding_width number?
---@field on_change fun(binding: rizu.config.KeyBinding)?

---@class ui.views.form.Keybind : ui.views.form.FormControl
---@operator call: ui.views.form.Keybind
---@field binding rizu.config.KeyBinding
---@field preview_binding rizu.config.KeyBinding?
---@field font love.Font
---@field label_text string
---@field binding_width number
---@field on_change fun(binding: rizu.config.KeyBinding)?
---@field cap_left gui.Sprite
---@field cap_middle gui.Sprite
---@field cap_right gui.Sprite
local Keybind = FormControl + {}

local HEIGHT = 40
local DEFAULT_BINDING_WIDTH = 300
local TEXT_PADDING = 9

local MODIFIER_KEYS = {
	lalt = true,
	ralt = true,
	lctrl = true,
	rctrl = true,
	lgui = true,
	rgui = true,
	lshift = true,
	rshift = true,
}

---@param binding rizu.config.KeyBinding
---@return rizu.config.KeyBinding
local function copyBinding(binding)
	return {
		key = binding.key,
		control = binding.control == true,
		shift = binding.shift == true,
		alt = binding.alt == true,
		super = binding.super == true,
		allow_repeat = binding.allow_repeat,
	}
end

---@param params ui.views.form.KeybindParams
function Keybind:new(params)
	FormControl.new(self)
	self.binding = copyBinding(params.binding)
	self.preview_binding = nil
	self.font = Resources.getFont("medium", 16)
	self.label_text = params.label
	self.on_change = params.on_change
	self.cap_left = Resources.sprites.form_element_cap_left
	self.cap_middle = Resources.sprites.form_element_cap_middle
	self.cap_right = Resources.sprites.form_element_cap_right

	local width = params.width or 300
	self.binding_width = params.binding_width or math.min(DEFAULT_BINDING_WIDTH, width)
	assert(self.binding_width >= self.cap_left:getWidth() + self.cap_right:getWidth(),
		"keybind textbox width is too small")
	assert(self.binding_width <= width, "keybind textbox cannot be wider than the control")
	self:setSize(width, HEIGHT)
	self:setClip(true)
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
end

---@return rizu.config.KeyBinding
function Keybind:getBinding()
	return copyBinding(self.binding)
end

---@param binding rizu.config.KeyBinding
---@param notify boolean?
function Keybind:setBinding(binding, notify)
	self.binding = copyBinding(binding)
	if notify and self.on_change then
		self.on_change(self:getBinding())
	end
end

---@param modifiers gui.UIEvent
---@return boolean activated
function Keybind:activate(modifiers)
	assert(self.screen and self.screen.inputs, "keybind is not attached to an input-enabled screen")
	self.preview_binding = {
		key = "",
		control = modifiers.control_pressed,
		shift = modifiers.shift_pressed,
		alt = modifiers.alt_pressed,
		super = modifiers.super_pressed,
	}
	self.screen.inputs:setKeyboardFocus(self, {
		control = modifiers.control_pressed,
		shift = modifiers.shift_pressed,
		alt = modifiers.alt_pressed,
		super = modifiers.super_pressed,
	})
	return true
end

---@param e gui.MouseClickEvent
---@return boolean?
function Keybind:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	return self:activate(e)
end

---@param e gui.FocusLostEvent
function Keybind:onFocusLost(e)
	self.preview_binding = nil
end

---@param e gui.KeyDownEvent
---@return boolean?
function Keybind:onKeyDown(e)
	if not self.focused or e.is_repeated then
		return
	end
	self.preview_binding = {
		key = MODIFIER_KEYS[e.key] and "" or e.key,
		control = e.control_pressed,
		shift = e.shift_pressed,
		alt = e.alt_pressed,
		super = e.super_pressed,
	}
	return true
end

---@param e gui.KeyUpEvent
---@return boolean?
function Keybind:onKeyUp(e)
	local preview = self.preview_binding
	if not self.focused or not preview then
		return
	end
	if e.key ~= preview.key then
		if preview.key == "" then
			preview.control = e.control_pressed
			preview.shift = e.shift_pressed
			preview.alt = e.alt_pressed
			preview.super = e.super_pressed
		end
		return true
	end

	self:setBinding(preview, true)
	assert(self.screen and self.screen.inputs)
	self.screen.inputs:setKeyboardFocus(nil, {
		control = e.control_pressed,
		shift = e.shift_pressed,
		alt = e.alt_pressed,
		super = e.super_pressed,
	})
	return true
end

function Keybind:draw()
	Painter.snapToPixel()
	love.graphics.setFont(self.font)
	Painter.setColorTable(Colors.text)
	love.graphics.print(self.label_text, 0, (HEIGHT - self.font:getHeight()) / 2)

	local body_x = self.width - self.binding_width
	local left_width = self.cap_left:getWidth()
	local right_width = self.cap_right:getWidth()
	local middle_width = self.binding_width - left_width - right_width
	Painter.setColorTable(Colors.background)
	self.cap_left:draw(body_x, 0)
	self.cap_middle:draw(body_x + left_width, 0, 0, middle_width / self.cap_middle:getWidth(), 1)
	self.cap_right:draw(self.width - right_width, 0)

	local text ---@type string
	local preview = self.preview_binding
	if self.focused and preview then
		if preview.key == "" and not (preview.control or preview.shift or preview.alt or preview.super) then
			text = "Press any button..."
			Painter.setColorTable(Colors.text_muted)
		else
			local parts = {} ---@type string[]
			if preview.control then parts[#parts + 1] = "Ctrl" end
			if preview.shift then parts[#parts + 1] = "Shift" end
			if preview.alt then parts[#parts + 1] = "Alt" end
			if preview.super then parts[#parts + 1] = "Super" end
			if preview.key ~= "" then parts[#parts + 1] = preview.key end
			text = table.concat(parts, "+")
			Painter.setColorTable(Colors.accent)
		end
	else
		text = KeyBindings.format({self.binding})
		Painter.setColorTable(Colors.text)
	end
	love.graphics.print(text, body_x + TEXT_PADDING, (HEIGHT - self.font:getHeight()) / 2)
end

return Keybind
