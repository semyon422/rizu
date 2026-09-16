local Sprite = require("gui.Sprite")

---@class gui.AtlasImage : gui.Sprite
---@operator call: gui.AtlasImage
---@field atlas love.Image
---@field quad love.Quad
---@field width number Source-pixel width
---@field height number Source-pixel height
local AtlasImage = Sprite + {}

---@param atlas love.Image
---@param quad love.Quad
---@param pixel_ratio number?
function AtlasImage:new(atlas, quad, pixel_ratio)
	Sprite.new(self, pixel_ratio)
	self.atlas = atlas
	self.quad = quad

	local _, _, width, height = quad:getViewport()
	self.width = width
	self.height = height
end

---@param x number?
---@param y number?
---@param r number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
---@param kx number?
---@param ky number?
function AtlasImage:draw(x, y, r, sx, sy, ox, oy, kx, ky)
	local ratio = self.pixel_ratio
	love.graphics.draw(
		self.atlas, self.quad, x, y, r,
		(sx or 1) / ratio,
		(sy or sx or 1) / ratio,
		ox and ox * ratio,
		oy and oy * ratio,
		kx, ky
	)
end

---@return number
function AtlasImage:getWidth()
	return self.width / self.pixel_ratio
end

---@return number
function AtlasImage:getHeight()
	return self.height / self.pixel_ratio
end

---@return number
---@return number
function AtlasImage:getDimensions()
	return self:getWidth(), self:getHeight()
end

function AtlasImage:release()
	self.quad:release()
end

return AtlasImage
