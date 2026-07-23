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
	self.model = TextboxModel()
	self.model:setText(params.text or "")
	self.font = Resources.getFont("regular", 24)
	self.width = params.width or 300
	self.height = self.font:getHeight() + 12
	self.offset_max = {self.width, self.height}
	self.on_change = params.on_change
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
end

---@return string
function Textbox:getText()
	return self.model:getText()
end

---@param text string
function Textbox:setText(text)
	self.model:setText(text)
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
	lg.setColor(0.12, 0.12, 0.15)
	lg.rectangle("fill", 0, 0, self.width, self.height)
	lg.setColor(0.8, 0.8, 0.85)
	lg.rectangle("line", 0, 0, self.width, self.height)
	lg.setColor(1, 1, 1)
	lg.setFont(self.font)
	local text_x = 6
	local text_y = 6
	lg.setScissor(0, 0, self.world_transform:transformPoint(self.width, self.height))
	lg.print(self.model:getText(), text_x, text_y)
	if self.focused then
		local left = self.model:getSplit()
		local cursor_x = text_x + self.font:getWidth(left)
		lg.rectangle("fill", cursor_x, text_y, 2, self.font:getHeight())
	end
	lg.setScissor()
end

return Textbox
