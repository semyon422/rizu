local class = require("class")

---@class rizu.skin.osu.mania.OsuManiaBatch
---@operator call: rizu.skin.osu.mania.OsuManiaBatch
---@field pages {[love.Image]: love.SpriteBatch}
---@field current love.SpriteBatch?
---@field collecting boolean
local OsuManiaBatch = class()
local CAPACITY = 2048

function OsuManiaBatch:new()
	self.pages = {}
	self.collecting = false
end

---@param image love.Image
function OsuManiaBatch:loadPage(image)
	self.pages[image] = love.graphics.newSpriteBatch(image, CAPACITY, "stream")
end

-- Flush before changing transform, blend, shader, scissor, or drawing a standalone texture.
function OsuManiaBatch:flush()
	local batch = self.current
	if not batch then return end
	local lg = love.graphics
	local r, g, b, a = lg.getColor()
	lg.setColor(1, 1, 1, 1)
	lg.draw(batch)
	lg.setColor(r, g, b, a)
	batch:clear()
	self.current = nil
end

function OsuManiaBatch:begin()
	assert(not self.collecting, "nested mania batch scope")
	self.collecting = true
end

function OsuManiaBatch:finish()
	self:flush()
	self.collecting = false
end

---@param texture love.Image
---@param quad love.Quad
---@param x number
---@param y number
---@param rotation number
---@param sx number
---@param sy number
---@param ox number
---@param oy number
function OsuManiaBatch:add(texture, quad, x, y, rotation, sx, sy, ox, oy)
	local batch = assert(self.pages[texture], "atlas batch not loaded")
	if self.current ~= batch or batch:getCount() == CAPACITY then self:flush() end
	self.current = batch
	batch:setColor(love.graphics.getColor())
	batch:add(quad, x, y, rotation, sx, sy, ox, oy)
	if not self.collecting then self:flush() end
end

function OsuManiaBatch:unload()
	for _, batch in pairs(self.pages) do batch:release() end
	self.pages = {}
	self.current = nil
	self.collecting = false
end

return OsuManiaBatch
