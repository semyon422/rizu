local BaseButton = require("ui.base.Button")

---@class yi.ButtonParams
---@field atlas love.Image
---@field button_quad love.Quad
---@field pixel love.Quad
---@field font love.Font
---@field button_color number[]?
---@field text_color number[]?
---@field text string?
---@field on_click fun(button: yi.Button)?

---@class yi.Button : ui.Button
---@overload fun(params: yi.ButtonParams): yi.Button
---@field atlas love.Image
---@field button_quad love.Quad
---@field pixel love.Quad
---@field font love.Font
---@field button_color number[]?
---@field text_color number[]?
---@field text string
---@field on_click fun(button: yi.Button)?
---@field text_batch love.Text
local Button = BaseButton + {}

---@param params yi.ButtonParams
function Button:new(params)
	BaseButton.new(self)
	self.atlas = assert(params.atlas, "Button atlas is required")
	self.button_quad = assert(params.button_quad, "Button quad is required")
	self.pixel = assert(params.pixel, "Button pixel quad is required")
	self.font = assert(params.font, "Button font is required")
	self.button_color = assert(params.button_color, "Button color is requried")
	self.text_color = assert(params.text_color, "Text color is required")
	self.text = params.text or ""
	self.on_click = params.on_click
	self.text_batch = love.graphics.newText(self.font, self.text)
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
	lg.draw(text_batch, w / 2 - tw / 2, h / 2 - th / 2)
end

return Button
