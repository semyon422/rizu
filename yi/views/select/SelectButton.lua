local View = require("yi.views.View")
local Colors = require("yi.Colors")

---@class yi.SelectButton : yi.View
---@overload fun(): yi.Button
---@field callback function?
---@field icon string?
---@field active boolean?
local SelectButton = View + {}

SelectButton.id = "SelectButton"

function SelectButton:load()
	View.load(self)
	self.handles_mouse_input = true

	local res = self:getResources()
	self.icon_batch = love.graphics.newTextBatch(res:getFont("icons", 24), self.icon)
	self.icon_x = 0
	self.icon_y = 0
end

function SelectButton:updateTransforms()
	View.updateTransforms(self)
	local w, h = self:getCalculatedWidth(), self:getCalculatedHeight()

	local iw, ih = self.icon_batch:getDimensions()

	self.icon_x = math.floor((w - iw) / 2)
	self.icon_y = math.floor((h - ih) / 2)
end

function SelectButton:onMouseDown(_)
	if self.callback then
		self.callback()
	end
	return true
end

function SelectButton:draw()
	local w, h = self:getCalculatedWidth(), self:getCalculatedHeight()

	local bg_color = self.active and Colors.accent or (self.mouse_over and Colors.button_hover or Colors.button)
	local border_color = self.active and Colors.accent or (self.mouse_over and Colors.accent or Colors.outline)
	local border_width = (self.active or self.mouse_over) and 2 or 1
	local icon_color = self.active and {0, 0, 0, 1} or Colors.text

	love.graphics.setColor(bg_color)
	love.graphics.rectangle("fill", 0, 0, w, h, 4, 4)

	love.graphics.setLineWidth(border_width)
	love.graphics.setColor(border_color)
	if self.active or self.mouse_over then
		love.graphics.rectangle("line", 1, 1, w - 2, h - 2, 4, 4)
	end

	love.graphics.setColor(icon_color)
	love.graphics.draw(self.icon_batch, self.icon_x, self.icon_y)
end

SelectButton.Setters = setmetatable({
	callback = true,
	icon = true,
	active = true,
}, {__index = View.Setters})

return SelectButton
