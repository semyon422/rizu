local FormControl = require("ui.views.form.FormControl")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local TextboxModel = require("ui.helpers.TextboxModel")

---@class ui.views.form.TextboxParams
---@field label string
---@field text string?
---@field placeholder string?
---@field width number?
---@field on_change fun(text: string)?

---@class ui.views.form.Textbox : ui.views.form.FormControl
---@operator call: ui.views.form.Textbox
---@field model ui.helpers.TextboxModel
---@field font love.Font
---@field label_text string
---@field placeholder string
---@field on_change fun(text: string)?
---@field cap_left gui.Sprite
---@field cap_middle gui.Sprite
---@field cap_right gui.Sprite
local Textbox = FormControl + {}

local HEIGHT = 65
local BODY_Y = 25
local TEXT_X = 9
local TEXT_Y = 35

---@param params ui.views.form.TextboxParams
function Textbox:new(params)
	FormControl.new(self)
	self.model = TextboxModel()
	self.model:setText(params.text or "")
	self.font = Resources.getFont("medium", 16)
	self.label_text = params.label
	self.placeholder = params.placeholder or ""
	self.on_change = params.on_change
	self.cap_left = Resources.sprites.form_element_cap_left
	self.cap_middle = Resources.sprites.form_element_cap_middle
	self.cap_right = Resources.sprites.form_element_cap_right

	local width = params.width or 300
	assert(width >= self.cap_left:getWidth() + self.cap_right:getWidth(), "textbox width is too small")
	self:setSize(width, HEIGHT)
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
	end
end

function Textbox:notifyChange()
	if self.on_change then
		self.on_change(self.model:getText())
	end
end

---@param e gui.MouseClickEvent
---@return boolean
function Textbox:onMouseClick(e)
	if e.button == 1 then
		assert(self.screen and self.screen.inputs, "textbox is not attached to an input-enabled screen")
		self.screen.inputs:setKeyboardFocus(self, {
			control = e.control_pressed,
			shift = e.shift_pressed,
			alt = e.alt_pressed,
			super = e.super_pressed,
		})
	end
	return true
end

---@param e gui.TextInputEvent
---@return boolean?
function Textbox:onTextInput(e)
	if not self.focused then
		return
	end
	if self.model:insert(e.text or "") then
		self:notifyChange()
	end
	return true
end

---@param e gui.KeyDownEvent
---@return boolean?
function Textbox:onKeyDown(e)
	if not self.focused then
		return
	end
	local changed = false
	if e.key == "backspace" then
		changed = self.model:backspace()
	elseif e.key == "delete" then
		changed = self.model:delete()
	elseif e.key == "left" then
		self.model:moveLeft()
	elseif e.key == "right" then
		self.model:moveRight()
	elseif e.key == "home" then
		self.model:moveToStart()
	elseif e.key == "end" then
		self.model:moveToEnd()
	else
		return
	end
	if changed then
		self:notifyChange()
	end
	return true
end

function Textbox:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font)
	love.graphics.print(self.label_text, 0, 0)

	local left_width = self.cap_left:getWidth()
	local right_width = self.cap_right:getWidth()
	local middle_width = self.width - left_width - right_width
	Painter.setColorTable(Colors.background)
	self.cap_left:draw(0, BODY_Y)
	self.cap_middle:draw(left_width, BODY_Y, 0, middle_width / self.cap_middle:getWidth(), 1)
	self.cap_right:draw(self.width - right_width, BODY_Y)

	local text = self.model:getText()
	Painter.setColorTable(text == "" and Colors.text_muted or Colors.text)
	love.graphics.print(text == "" and self.placeholder or text, TEXT_X, TEXT_Y)

	if self.focused then
		local left = self.model:getSplit()
		Painter.setColorTable(Colors.text)
		Resources.sprites.pixel:draw(TEXT_X + self.font:getWidth(left), TEXT_Y, 0, 2, self.font:getHeight())
	end
end

return Textbox
