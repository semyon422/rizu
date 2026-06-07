local class = require("class")
local math_util = require("aqua.math_util")

---@class gui.Box
---@operator call: gui.Box
local Box = class()

function Box:new()
	self.x = 0
	self.y = 0
	self.width = 0
	self.height = 0
	self.transform = math_util.newTransform()
end

---@param x number
---@param y number
---@param width number
---@param height number
function Box:update(x, y, width, height)
	self.x = x
	self.y = y
	self.width = width
	self.height = height
	self.transform:setTransformation(x, y)
end

---@return number
---@return number
function Box:getDimensions()
	return self.width, self.height
end

return Box
