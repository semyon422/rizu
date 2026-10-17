local Sprite = require("gui.Sprite")

---@class gui.ImageSprite : gui.Sprite
---@operator call: gui.ImageSprite
---@field image love.Image
local ImageSprite = Sprite + {}

---@param image love.Image
---@param pixel_ratio number?
function ImageSprite:new(image, pixel_ratio)
	Sprite.new(self, pixel_ratio)
	self.image = image
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
function ImageSprite:draw(x, y, r, sx, sy, ox, oy, kx, ky)
	local ratio = self.pixel_ratio
	love.graphics.draw(
		self.image, x, y, r,
		(sx or 1) / ratio,
		(sy or sx or 1) / ratio,
		ox and ox * ratio,
		oy and oy * ratio,
		kx, ky
	)
end

---@return number
function ImageSprite:getWidth()
	return self.image:getWidth() / self.pixel_ratio
end

---@return number
function ImageSprite:getHeight()
	return self.image:getHeight() / self.pixel_ratio
end

---@return number
---@return number
function ImageSprite:getDimensions()
	return self:getWidth(), self:getHeight()
end

function ImageSprite:release()
	self.image:release()
end

return ImageSprite
