local View = require("gui.View")

---@alias ui.views.ImageMode "native"|"fit"

---@class ui.views.Image : gui.View
---@operator call: ui.views.Image
---@field texture love.Texture
---@field quad love.Quad
---@field mode ui.views.ImageMode
---@field image_width number
---@field image_height number
local Image = View + {}

---@param texture love.Texture
---@param quad love.Quad
---@param mode ui.views.ImageMode?
function Image:new(texture, quad, mode)
	View.new(self)
	self.texture = texture
	self.quad = quad
	self.mode = mode or "native"
	assert(self.mode == "native" or self.mode == "fit", "invalid image mode")

	local _, _, width, height = self.quad:getViewport()
	self.image_width = width
	self.image_height = height
	if self.mode == "native" then
		self:setSize(width, height)
	end
end

local lg = love.graphics

function Image:draw()
	if self.mode == "fit" then
		lg.draw(self.texture, self.quad, 0, 0, 0, self.width / self.image_width, self.height / self.image_height)
		return
	end
	lg.draw(self.texture, self.quad)
end

return Image
