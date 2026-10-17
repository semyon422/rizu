local class = require("class")

---@class gui.Sprite
---@operator call: gui.Sprite
---@field pixel_ratio number Source pixels per logical pixel
local Sprite = class()

---@param pixel_ratio number?
function Sprite:new(pixel_ratio)
	pixel_ratio = pixel_ratio or 1
	assert(type(pixel_ratio) == "number" and pixel_ratio > 0 and pixel_ratio < math.huge,
		"pixel ratio must be a positive finite number")
	self.pixel_ratio = pixel_ratio
end

---@return number
function Sprite:getPixelRatio()
	return self.pixel_ratio
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
function Sprite:draw(x, y, r, sx, sy, ox, oy, kx, ky)
	error("not implemented")
end

---@return number
function Sprite:getWidth()
	error("not implemented")
end

---@return number
function Sprite:getHeight()
	error("not implemented")
end

---@return number
---@return number
function Sprite:getDimensions()
	error("not implemented")
end

function Sprite:release()
	error("not implemented")
end

return Sprite
