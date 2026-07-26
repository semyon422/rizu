local Sprite = require("gui.Sprite")

---@class gui.AtlasImage : gui.Sprite
---@operator call: gui.AtlasImage
---@field atlas love.Image
---@field quad love.Quad
---@field width number
---@field height number
local AtlasImage = Sprite + {}

---@param atlas love.Image
---@param quad love.Quad
function AtlasImage:new(atlas, quad)
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
	love.graphics.draw(self.atlas, self.quad, x, y, r, sx, sy, ox, oy, kx, ky)
end

---@return number
function AtlasImage:getWidth()
	return self.width
end

---@return number
function AtlasImage:getHeight()
	return self.height
end

---@return number
---@return number
function AtlasImage:getDimensions()
	return self.width, self.height
end

function AtlasImage:release()
	self.quad:release()
end

return AtlasImage
