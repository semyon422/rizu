local Sprite = require("gui.Sprite")

---@class gui.ImageSprite : gui.Sprite
---@operator call: gui.ImageSprite
---@field image love.Image
local ImageSprite = Sprite + {}

---@param image love.Image
function ImageSprite:new(image)
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
	love.graphics.draw(self.image, x, y, r, sx, sy, ox, oy, kx, ky)
end

---@return number
function ImageSprite:getWidth()
	return self.image:getWidth()
end

---@return number
function ImageSprite:getHeight()
	return self.image:getHeight()
end

---@return number
---@return number
function ImageSprite:getDimensions()
	return self.image:getDimensions()
end

function ImageSprite:release()
	self.image:release()
end

return ImageSprite
