local HudElement = require("rizu.skin.hud.HudElement")

local lg = love.graphics

local SEGMENTS = 50
local SEGMENT_WIDTH = 8
local STEP = 9 -- segment and its 1px gap in gauge.png
local TREMBLE = 2 -- LR2 hides up to this many segments under the top one, redrawn every frame

---Which segments are lit, as LR2 draws them: the top one always, the ones right under it flicker off.
---@param count integer Lit segments before the flicker, 0..SEGMENTS.
---@param off integer How many segments under the top one are off, 0..TREMBLE.
---@param i integer Segment, 1 is the lowest.
---@return boolean
local function is_lit(count, off, i)
	return i <= count and (i < count - off or i >= count or i == 1)
end

---@class IidxGauge.Strip
---@field texture love.Image
---@field quads love.Quad[]
---@field density number
---@field height number

---A gauge of 50 segments with the LR2 flicker on its top ones.
---@class rizu.skin.hud.elements.IidxGauge : rizu.skin.hud.HudElement
---@operator call: rizu.skin.hud.elements.IidxGauge
---@field count integer
---@field flicker_time number Seconds since the flicker last changed.
---@field off integer
---@field on IidxGauge.Strip? Lit segments.
---@field off_strip IidxGauge.Strip? Unlit segments.
local IidxGauge = HudElement + {}

IidxGauge.label = "IIDX gauge"
IidxGauge.is_lit = is_lit
IidxGauge.fields = {
	{key = "texture", label = "Texture", type = "texture", default = "stage/gauge"},
	{key = "texture_off", label = "Off texture", type = "texture", default = "stage/gauge_off"},
	{key = "flicker", label = "Flicker", type = "checkbox", default = true},
	{key = "flicker_rate", label = "Flicker rate", min = 1, max = 60, step = 1, default = 40},
}

---@param values {[string]: any}?
---@param textures rizu.skin.SkinTextures
function IidxGauge:new(values, textures)
	self.count, self.off, self.flicker_time = 0, 0, 0
	HudElement.new(self, values, textures)
	self.width, self.height = SEGMENTS * STEP - 1, 0
end

---@return rizu.skin.SkinTextures.Asset[]
function IidxGauge:getAssets()
	return {
		{name = self.values.texture --[[@as string]], group = HudElement.group},
		{name = self.values.texture_off --[[@as string]], group = HudElement.group},
	}
end

---Cuts one row of segments from its atlas region.
---@param image rizu.skin.SkinTextures.Image?
---@return IidxGauge.Strip?
local function cut(image)
	if not image then return end
	local frame = image --[[@as rizu.skin.SkinTextures.Frame]]
	local texture = frame.texture or image --[[@as love.Image]]
	local x, y, w, h = 0, 0, texture:getDimensions()
	if frame.quad then x, y, w, h = frame.quad:getViewport() end
	local density = frame.density or 1
	local quads = {} ---@type love.Quad[]
	for i = 1, SEGMENTS do
		quads[i] = lg.newQuad(x + (i - 1) * STEP * density, y, SEGMENT_WIDTH * density, h, texture)
	end
	return {texture = texture, quads = quads, density = density, height = h / density}
end

---@param context rizu.api.GameApi
function IidxGauge:load(context)
	HudElement.load(self, context)
	self.on = cut(self:getTexture(self.values.texture --[[@as string]]))
	self.off_strip = cut(self:getTexture(self.values.texture_off --[[@as string]]))
	local strip = self.on or self.off_strip
	self.height = strip and strip.height or 0
end

---@param context rizu.api.GameApi?
function IidxGauge:unload(context)
	for _, strip in pairs({on = self.on, off = self.off_strip}) do
		for _, quad in ipairs(strip.quads) do quad:release() end
	end
	self.on, self.off_strip, self.count, self.off = nil, nil, 0, 0
	HudElement.unload(self, context)
end

---@param dt number
---@param context rizu.api.GameApi
function IidxGauge:update(dt, context)
	local health = context.gameplay:getHealths() or 0
	self.count = math.ceil(health * SEGMENTS)
	self.flicker_time = self.flicker_time + dt
	if not self.values.flicker then
		self.off = 0
	elseif self.flicker_time * (self.values.flicker_rate --[[@as number]]) >= 1 then
		self.flicker_time = 0
		self.off = math.random(0, TREMBLE)
	end
end

---@param strip IidxGauge.Strip
---@param i integer
local function draw_segment(strip, i)
	local scale = 1 / strip.density
	lg.draw(strip.texture, strip.quads[i], (i - 1) * STEP, 0, 0, scale, scale)
end

function IidxGauge:draw()
	lg.setColor(1, 1, 1, 1)
	for i = 1, SEGMENTS do
		if self.off_strip then draw_segment(self.off_strip, i) end -- the background, as in LR2
		if self.on and is_lit(self.count, self.off, i) then draw_segment(self.on, i) end
	end
end

return IidxGauge
