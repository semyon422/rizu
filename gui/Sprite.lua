local class = require("class")

---@class gui.Sprite
---@operator call: gui.Sprite
local Sprite = class()

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
