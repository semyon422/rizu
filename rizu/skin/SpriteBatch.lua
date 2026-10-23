local class = require("class")

---@class rizu.skin.SpriteBatch
---@operator call: rizu.skin.SpriteBatch
---@field pages {[love.Image]: love.SpriteBatch}
---@field private current love.SpriteBatch?
---@field private scope_depth integer
local SpriteBatch = class()
local CAPACITY = 2048

function SpriteBatch:new()
	self.pages = {}
	self.scope_depth = 0
end

---@param image love.Image
function SpriteBatch:loadPage(image)
	self.pages[image] = love.graphics.newSpriteBatch(image, CAPACITY, "stream")
end

---Flush before changing transform, blend, shader, scissor, or drawing primitives.
function SpriteBatch:flush()
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

---@param texture love.Image
---@param quad love.Quad
---@param x number
---@param y number
---@param rotation number
---@param sx number
---@param sy number
---@param ox number
---@param oy number
function SpriteBatch:add(texture, quad, x, y, rotation, sx, sy, ox, oy)
	local batch = assert(self.pages[texture], "atlas batch not loaded")
	if self.current ~= batch or batch:getCount() == CAPACITY then self:flush() end
	self.current = batch
	batch:setColor(love.graphics.getColor())
	batch:add(quad, x, y, rotation, sx, sy, ox, oy)
	if self.scope_depth == 0 then self:flush() end
end

-- Scopes nest without callers inspecting batch state. The outer owner must
-- finish before restoring its graphics transform; inner draws may flush sooner.
function SpriteBatch:begin()
	self.scope_depth = self.scope_depth + 1
end

function SpriteBatch:finish()
	assert(self.scope_depth > 0, "no active sprite batch scope")
	self.scope_depth = self.scope_depth - 1
	if self.scope_depth == 0 then self:flush() end
end

function SpriteBatch:unload()
	for _, batch in pairs(self.pages) do batch:release() end
	self.pages = {}
	self.current = nil
	self.scope_depth = 0
end

return SpriteBatch
