local class = require("class")

---@class rizu.skin.osu.mania.OsuManiaBatch
---@operator call: rizu.skin.osu.mania.OsuManiaBatch
---@field pages {[love.Image]: love.SpriteBatch}
---@field current love.SpriteBatch?
---@field collecting boolean
---@field restore_blend_mode string?
---@field restore_blend_alpha_mode string?
local OsuManiaBatch = class()
local CAPACITY = 2048

function OsuManiaBatch:new()
	self.pages = {}
	self.collecting = false
	self.restore_blend_mode = nil
	self.restore_blend_alpha_mode = nil
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

function OsuManiaBatch:setBlendMode(mode, alpha_mode)
	local current_mode, current_alpha_mode = love.graphics.getBlendMode()
	if current_mode == mode and current_alpha_mode == alpha_mode then return end
	self:flush()
	love.graphics.setBlendMode(mode, alpha_mode)
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

function OsuManiaBatch:begin()
	assert(not self.collecting, "nested mania batch scope")
	self.restore_blend_mode, self.restore_blend_alpha_mode = love.graphics.getBlendMode()
	self.collecting = true
end

function OsuManiaBatch:finish()
	self:flush()
	if self.restore_blend_mode then
		self:setBlendMode(self.restore_blend_mode, self.restore_blend_alpha_mode)
	end
	self.restore_blend_mode, self.restore_blend_alpha_mode = nil, nil
	self.collecting = false
end

function OsuManiaBatch:unload()
	for _, batch in pairs(self.pages) do batch:release() end
	self.pages = {}
	self.current = nil
	self.collecting = false
	self.restore_blend_mode = nil
	self.restore_blend_alpha_mode = nil
end

return OsuManiaBatch
