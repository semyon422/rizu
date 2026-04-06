local View = require("ui.View")
local Painter = require("yi.Painter")

---@class yi.ButtonParams
---@field atlas love.Image
---@field button_quad love.Quad
---@field pixel love.Quad
---@field resources yi.Resources
---@field font_name yi.FontName
---@field font_size integer
---@field button_color number[]
---@field text_color number[]
---@field text string
---@field on_click fun(button: yi.Button)?

---@class yi.Button : ui.View
---@overload fun(params: yi.ButtonParams): yi.Button
---@field atlas love.Image
---@field button_quad love.Quad
---@field pixel love.Quad
---@field font love.Font
---@field resources yi.Resources
---@field font_name yi.FontName
---@field font_size integer
---@field button_color number[]
---@field text_color number[]
---@field text string
---@field on_click? fun()
---@field text_batch love.Text
local Button = View + {}

---@private
function Button:rebuildText()
	self.font = self.resources:getScaledFont(self.font_name, self.font_size, self.ui_scale)
	self.text_batch = love.graphics.newText(self.font, self.text)
end

---@param params yi.ButtonParams
function Button:new(params)
	View.new(self)
	self.atlas = assert(params.atlas, "Button atlas is required")
	self.button_quad = assert(params.button_quad, "Button quad is required")
	self.pixel = assert(params.pixel, "Button pixel quad is required")
	self.resources = assert(params.resources, "Button resources are required")
	self.font_name = assert(params.font_name, "Button font_name is required")
	self.font_size = assert(params.font_size, "Button font_size is required")
	self.button_color = assert(params.button_color, "Button color is requried")
	self.text_color = assert(params.text_color, "Text color is required")
	self.text = assert(params.text, "Button text is required")
	self.on_click = params.on_click
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self.is_focusable = true
	self:rebuildText()
end

---@return boolean
function Button:click()
	if self.on_click then
		self.on_click()
		return true
	end
	return false
end

---@param e ui.KeyDownEvent
function Button:onKeyDown(e)
	if e.key == "return" then
		return self:click()
	end
end

---@param e ui.MouseClickEvent
function Button:onMouseClick(e)
	if e.button == 1 then
		return self:click()
	end
end

function Button:onLayoutUpdate()
	self:rebuildText()
end

function Button:draw()
	local atlas = self.atlas
	local button_quad = self.button_quad
	local pixel = self.pixel
	local w, h = self.width, self.height
	local _, _, quad_w, quad_h = button_quad:getViewport()
	local cap_scale = h / quad_h
	local cap_w = math.min(w / 2, quad_w * cap_scale)
	local inner_w = math.max(0, w - cap_w * 2)
	local cap_sx = cap_w / quad_w
	local cap_sy = h / quad_h
	local text_batch = self.text_batch
	local tw, th = text_batch:getDimensions()
	tw = self:toLogicalSize(tw)
	th = self:toLogicalSize(th)
	local lg = love.graphics

	lg.setColor(self.button_color)
	lg.draw(atlas, button_quad, 0, 0, 0, cap_sx, cap_sy)
	lg.draw(atlas, button_quad, w, 0, 0, -cap_sx, cap_sy)

	if inner_w > 0 then
		lg.draw(atlas, pixel, cap_w, 0, 0, inner_w, h)
	end

	if self.focused then
		love.graphics.setColor(1, 1, 1)
		love.graphics.rectangle("line", 0, 0, w, h)
	end

	lg.setColor(self.text_color)
	Painter.drawText(text_batch, w / 2 - tw / 2, h / 2 - th / 2)
end

return Button
