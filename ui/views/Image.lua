local View = require("gui.View")
local Painter = require("gui.Painter")

---@alias ui.views.ImageMode "native"|"fit"

---@class ui.views.Image : gui.View
---@operator call: ui.views.Image
---@field sprite gui.Sprite
---@field mode ui.views.ImageMode
---@field image_width number
---@field image_height number
local Image = View + {}

---@param sprite gui.Sprite
---@param mode ui.views.ImageMode?
---@param color gui.Color?
function Image:new(sprite, mode, color)
	View.new(self)
	self.sprite = sprite
	self.mode = mode or "native"
	self.color = color or {1, 1, 1, 1}
	assert(self.mode == "native" or self.mode == "fit", "invalid image mode")

	self.image_width, self.image_height = sprite:getDimensions()
	if self.mode == "native" then
		self:setSize(self.image_width, self.image_height)
	end
end

function Image:draw()
	Painter.setColorTable(self.color)
	if self.mode == "fit" then
		self.sprite:draw(0, 0, 0, self.width / self.image_width, self.height / self.image_height)
		return
	end
	self.sprite:draw()
end

return Image
