local Painter = require("gui.Painter")
local View = require("gui.View")
local Resources = require("ui.Resources")
local TextboxModel = require("ui.helpers.TextboxModel")

---@class ui.views.Textbox : gui.View
---@operator call: ui.views.Textbox
---@field model ui.helpers.TextboxModel
---@field font love.Font
---@field on_change fun(text: string)?
local Textbox = View + {}

---@param params {text: string?, width: number?, on_change: fun(text: string)?}?
function Textbox:new(params)
	View.new(self)
	params = params or {}
	self:setClip(true)
	self.model = TextboxModel()
	self.model:setText(params.text or "")
	self.font = Resources.getFont("regular", 24)
	self:setSize(params.width or 300, self.font:getHeight() + 12)
	self.on_change = params.on_change
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
end

---@return string
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
function Textbox:onKeyDown(e)
	if not self.focused then
		return
	end
	local key = e.key
	local changed = false
	if key == "backspace" then
		changed = self.model:backspace()
	elseif key == "delete" then
		changed = self.model:delete()
	elseif key == "left" then
		self.model:moveLeft()
	elseif key == "right" then
		self.model:moveRight()
	elseif key == "home" then
		self.model:moveToStart()
	elseif key == "end" then
		self.model:moveToEnd()
	else
		return
	end
	if changed then
		self:notifyChange()
	end
	return true
end

local lg = love.graphics

function Textbox:draw()
	Painter.snapToPixel()
	Painter.setColorRgb(0.12, 0.12, 0.15)
	lg.rectangle("fill", 0, 0, self.width, self.height)
	Painter.setColorRgb(0.8, 0.8, 0.85)
	Painter.rectangleLineFixed(2, 2, self.width - 4, self.height - 5, 2)
	Painter.setColorRgb(1, 1, 1)
	lg.setFont(self.font)
	local text_x = 6
	local text_y = 6
	lg.print(self.model:getText(), text_x, text_y)
	if self.focused then
		local left = self.model:getSplit()
		local cursor_x = text_x + self.font:getWidth(left)
		lg.rectangle("fill", cursor_x, text_y, 2, self.font:getHeight())
	end
end

return Textbox
