local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local TextboxModel = require("ui.helpers.TextboxModel")
local UiActions = require("ui.UiActions")
local View = require("gui.View")

---@class ui.views.TextboxParams
---@field text string?
---@field placeholder string?
---@field icon gui.Sprite?
---@field on_change fun(text: string)?

---A standalone, single-line text input.
---@class ui.views.Textbox : gui.View
---@operator call: ui.views.Textbox
---@field model ui.helpers.TextboxModel
---@field font love.Font
---@field placeholder string
---@field icon gui.Sprite?
---@field on_change fun(text: string)?
---@field cap_left gui.Sprite
---@field cap_middle gui.Sprite
---@field cap_right gui.Sprite
---@field private committed_text string
local Textbox = View + {}

local WIDTH = 100
local HEIGHT = 40
local TEXT_X = 9
local TEXT_Y = 10
local ICON_RIGHT = 9

---@param params ui.views.TextboxParams?
function Textbox:new(params)
	View.new(self)
	params = params or {}
	self.model = TextboxModel()
	self.model:setText(params.text or "")
	self.committed_text = self.model:getText()
	self.font = Resources.getFont("medium", 16)
	self.placeholder = params.placeholder or ""
	self.icon = params.icon
	self.on_change = params.on_change
	self.cap_left = Resources.sprites.form_element_cap_left
	self.cap_middle = Resources.sprites.form_element_cap_middle
	self.cap_right = Resources.sprites.form_element_cap_right

	self:setSize(WIDTH, HEIGHT)
	self:setClip(true)
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
end

---@return string text
function Textbox:getText()
	return self.model:getText()
end

---@param text string
---@param notify boolean?
function Textbox:setText(text, notify)
	self.model:setText(text)
	if notify then
		self:notifyChange()
	else
		self.committed_text = text
	end
end

---@param icon gui.Sprite?
---@return ui.views.Textbox
function Textbox:setIcon(icon)
	self.icon = icon
	return self
end

function Textbox:notifyChange()
	local text = self.model:getText()
	if text == self.committed_text then
		return
	end
	self.committed_text = text
	if self.on_change then
		self.on_change(text)
	end
end

---@param e gui.FocusLostEvent
function Textbox:onFocusLost(e)
	self:notifyChange()
end

---@param modifiers gui.UIEvent
---@return boolean activated
function Textbox:activate(modifiers)
	assert(self.screen and self.screen.inputs, "textbox is not attached to an input-enabled screen")
	self.screen.inputs:setKeyboardFocus(self, {
		control = modifiers.control_pressed,
		shift = modifiers.shift_pressed,
		alt = modifiers.alt_pressed,
		super = modifiers.super_pressed,
	})
	return true
end

---@param e gui.MouseClickEvent
---@return boolean
function Textbox:onMouseClick(e)
	if e.button == 1 then
		return self:activate(e)
	end
	return false
end

---@param e gui.TextInputEvent
---@return boolean?
function Textbox:onTextInput(e)
	if not self.focused then
		return
	end
	self.model:insert(e.text or "")
	self:notifyChange()
	return true
end

---@param inputs gui.Inputs
function Textbox:onHandleInputs(inputs)
	if not self.focused then
		return
	end

	local changed = false
	if inputs:consumeActionJustPressed(UiActions.cancel)
		or inputs:consumeActionJustPressed(UiActions.accept)
	then
		inputs:setKeyboardFocus(nil, {control = false, shift = false, alt = false, super = false})
	elseif inputs:consumeActionJustPressed(UiActions.clear_field) then
		self.model:setText("")
		changed = true
	elseif inputs:consumeActionJustPressed(UiActions.delete_backward) then
		self.model:backspace()
		changed = true
	elseif inputs:consumeActionJustPressed(UiActions.delete_forward) then
		self.model:delete()
		changed = true
	elseif inputs:consumeActionJustPressed(UiActions.left) then
		self.model:moveLeft()
	elseif inputs:consumeActionJustPressed(UiActions.right) then
		self.model:moveRight()
	elseif inputs:consumeActionJustPressed(UiActions.move_to_start) then
		self.model:moveToStart()
	elseif inputs:consumeActionJustPressed(UiActions.move_to_end) then
		self.model:moveToEnd()
	end
	if changed then
		self:notifyChange()
	end
end

function Textbox:draw()
	Painter.snapToPixel()

	local left_width = self.cap_left:getWidth()
	local right_width = self.cap_right:getWidth()
	local middle_width = self.width - left_width - right_width
	Painter.setColorTable(Colors.elements)
	self.cap_left:draw(0, 0)
	self.cap_middle:draw(left_width, 0, 0, middle_width / self.cap_middle:getWidth(), 1)
	self.cap_right:draw(self.width - right_width, 0)

	local text = self.model:getText()
	Painter.setColorTable(text == "" and Colors.text_muted or Colors.text)
	love.graphics.setFont(self.font)
	love.graphics.print(text == "" and self.placeholder or text, TEXT_X, TEXT_Y)

	if self.focused then
		local left = self.model:getSplit()
		Painter.setColorTable(Colors.text)
		Resources.sprites.pixel:draw(TEXT_X + self.font:getWidth(left), TEXT_Y, 0, 2, self.font:getHeight())
	end

	if self.icon then
		local icon_width, icon_height = self.icon:getDimensions()
		Painter.setColorTable(Colors.text)
		self.icon:draw(self.width - ICON_RIGHT - icon_width, (HEIGHT - icon_height) / 2)
	end
end

return Textbox
