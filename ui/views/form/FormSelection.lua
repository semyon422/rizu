local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local View = require("gui.View")

---Animated background for the focused form control.
---@class ui.views.form.FormSelection : gui.View
---@operator call: ui.views.form.FormSelection
---@field target_x number?
---@field target_y number?
---@field target_width number?
---@field target_height number?
local FormSelection = View + {}

FormSelection.MOVE_DURATION = 0.27

function FormSelection:new()
	View.new(self)
	self.target_x = nil
	self.target_y = nil
	self.target_width = nil
	self.target_height = nil
	self:setVisible(false)
end

---@param x number
---@param y number
---@param width number
---@param height number
function FormSelection:moveToRect(x, y, width, height)
	if self.target_x == x and self.target_y == y
		and self.target_width == width and self.target_height == height
	then
		return
	end
	self.target_x = x
	self.target_y = y
	self.target_width = width
	self.target_height = height

	self:setSize(width, height)
	if not self.visible then
		self:setOffset(x, y)
		self:setVisible(true)
		return
	end

	self:moveTo(x, y, self.MOVE_DURATION, "OutQuint")
end

function FormSelection:hide()
	self.target_x = nil
	self.target_y = nil
	self.target_width = nil
	self.target_height = nil
	self:clearTransforms()
	self:setVisible(false)
end

function FormSelection:draw()
	Painter.setColorTable(Colors.hover)
	love.graphics.rectangle("fill", -10, -10, self.width + 20, self.height + 20)
end

return FormSelection
