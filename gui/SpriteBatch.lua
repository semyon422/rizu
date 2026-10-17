local class = require("class")
local AtlasImage = require("gui.AtlasImage")

---@class gui.SpriteBatch
---@operator call: gui.SpriteBatch
---@field atlas love.Image
---@field batch love.SpriteBatch
local SpriteBatch = class()

---@param sprite gui.AtlasImage
---@param size integer?
---@param usage love.SpriteBatchUsage?
function SpriteBatch:new(sprite, size, usage)
	assert(AtlasImage * sprite, "sprite batch requires an atlas sprite")
	self.atlas = sprite.atlas
	self.batch = love.graphics.newSpriteBatch(sprite.atlas, size, usage or "dynamic")
end

---@param color gui.Color|number
---@param g number?
---@param b number?
---@param a number?
function SpriteBatch:setColor(color, g, b, a)
	if type(color) == "table" then
		self.batch:setColor(color[1], color[2], color[3], color[4] or 1)
		return
	end
	self.batch:setColor(color, g, b, a)
end

function SpriteBatch:clear()
	self.batch:clear()
end

function SpriteBatch:flush()
	self.batch:flush()
end

---@param sprite gui.AtlasImage
---@param x number?
---@param y number?
---@param r number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
---@param kx number?
---@param ky number?
---@return integer id
function SpriteBatch:add(sprite, x, y, r, sx, sy, ox, oy, kx, ky)
	assert(sprite.atlas == self.atlas, "sprite belongs to a different atlas")
	return self.batch:add(sprite.quad, x, y, r, sx, sy, ox, oy, kx, ky)
end

function SpriteBatch:draw()
	love.graphics.draw(self.batch)
end

return SpriteBatch
