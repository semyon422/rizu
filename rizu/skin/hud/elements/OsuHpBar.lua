local HudElement = require("rizu.skin.hud.HudElement")
local TextureImage = require("rizu.skin.TextureImage")

local lg = love.graphics

local SPRITE_SCALE = 480 / 768
local FILL_X, FILL_Y = 7.5 / SPRITE_SCALE, 7.8 / SPRITE_SCALE
local MARKER_Y = (8.125 + 2.5) / SPRITE_SCALE
local LEGACY_FILL_X, LEGACY_FILL_Y = 3 / SPRITE_SCALE, 10 / SPRITE_SCALE
local INITIAL_RATE = 0.1 -- osu!: 0.02 of its 200 per millisecond
local FRAMERATE = 30 -- animated scorebar-colour frames per second
local KI = {"scorebar-ki", "scorebar-kidanger", "scorebar-kidanger2"}

---One texture and its region, so a fill can be cut to the width it shows.
---@param image rizu.skin.SkinTextures.Image
---@return love.Texture texture
---@return number x
---@return number y
---@return number width
---@return number height
---@return number density
local function region(image)
	local frame = image --[[@as rizu.skin.SkinTextures.Frame]]
	if frame.texture then
		local x, y, w, h = frame.quad:getViewport()
		return frame.texture, x, y, w, h, frame.density
	end
	local texture = image --[[@as love.Image]]
	local w, h = texture:getDimensions()
	return texture, 0, 0, w, h, 1
end

---osu!stable's health bar: scorebar-bg with scorebar-colour cut to the health and a marker at its end.
---Skins with their own colour and no scorebar-marker get the old ki icon that changes in danger.
---@class rizu.skin.hud.elements.OsuHpBar : rizu.skin.hud.HudElement
---@operator call: rizu.skin.hud.elements.OsuHpBar
---@field target number 0..1
---@field display number 0..1, follows target smoothly.
---@field initial boolean The first fill of the bar, until the health first drops.
---@field time number
---@field bg rizu.skin.SkinTextures.Image?
---@field fill rizu.skin.SkinTextures.Image[]
---@field marker rizu.skin.SkinTextures.Image?
---@field legacy boolean
---@field ki rizu.skin.SkinTextures.Image[]
---@field quad love.Quad?
local OsuHpBar = HudElement + {}

OsuHpBar.label = "osu!stable health bar"
OsuHpBar.defaults = {anchor = "top_left", origin = "top_left"}
OsuHpBar.fields = {
	{key = "texture_bg", label = "Background texture", type = "texture", default = "scorebar-bg"},
	{key = "texture_colour", label = "Fill texture", type = "texture", default = "scorebar-colour"},
	{key = "texture_marker", label = "Marker texture", type = "texture", default = "scorebar-marker"},
}

---@param values {[string]: any}?
---@param textures rizu.skin.SkinTextures
function OsuHpBar:new(values, textures)
	self.target, self.display, self.initial, self.time = 0, 0, true, 0
	self.fill, self.ki, self.legacy = {}, {}, false
	HudElement.new(self, values, textures)
end

---@return rizu.skin.SkinTextures.Asset[]
function OsuHpBar:getAssets()
	local group = HudElement.group
	local assets = {
		{name = self.values.texture_bg --[[@as string]], group = group},
		{name = self.values.texture_colour --[[@as string]], animation = true, group = group},
		{name = self.values.texture_marker --[[@as string]], group = group},
	}
	for _, name in ipairs(KI) do assets[#assets + 1] = {name = name, group = group} end
	return assets
end

---@param context rizu.api.GameApi
function OsuHpBar:load(context)
	HudElement.load(self, context)
	self.target, self.display, self.initial, self.time = 0, 0, true, 0
	self.bg = self:getTexture(self.values.texture_bg --[[@as string]])
	self.fill = self:getAnimation(self.values.texture_colour --[[@as string]])
	self.marker = self:getTexture(self.values.texture_marker --[[@as string]])
	local textures, group = self.textures, HudElement.group
	local skin_colour = textures:getAnimationFrames(self.values.texture_colour --[[@as string]], nil, group, true)
	local skin_marker = textures:getFrames(self.values.texture_marker --[[@as string]], nil, group, true)
	self.legacy = #skin_colour > 0 and #skin_marker == 0
	self.ki = {}
	if self.legacy then
		for i, name in ipairs(KI) do self.ki[i] = self:getTexture(name) end
	end
	if self.bg then
		local _, _, _, w, h, density = region(self.bg)
		self.width, self.height = w / density * SPRITE_SCALE, h / density * SPRITE_SCALE
	end
end

---@param context rizu.api.GameApi?
function OsuHpBar:unload(context)
	if self.quad then self.quad:release() end
	self.bg, self.fill, self.marker, self.ki, self.quad = nil, {}, nil, {}, nil
	HudElement.unload(self, context)
end

---@param dt number
---@param context rizu.api.GameApi
function OsuHpBar:update(dt, context)
	self.time = self.time + dt
	self.target = context.gameplay:getHealths() or 0
	local frames = dt * 60
	if self.display < self.target then
		if not self.initial then
			self.display = math.min(1, self.display + (self.target - self.display) / 4 * frames)
		elseif context.gameplay:getState() == "play" then
			self.display = math.min(self.target, self.display + INITIAL_RATE * dt)
		end
	elseif self.display > self.target then
		self.initial = false
		self.display = math.max(0, self.display - (self.display - self.target) / 6 * frames)
	end
end

function OsuHpBar:draw()
	local bg = self.bg
	if not bg then return end
	lg.push()
	lg.scale(SPRITE_SCALE)
	lg.setColor(1, 1, 1, 1)
	TextureImage.draw(bg, 0, 0)

	local fill_x = self.legacy and LEGACY_FILL_X or FILL_X
	local fill_y = self.legacy and LEGACY_FILL_Y or FILL_Y
	local shown = 0
	local fill = self.fill[#self.fill > 0 and math.floor(self.time * FRAMERATE) % #self.fill + 1 or 1]
	if fill then
		local texture, x, y, w, h, density = region(fill)
		shown = math.floor(w / density * self.display)
		if shown > 0 then
			-- Created here, the preview has no window when it loads.
			self.quad = self.quad or lg.newQuad(0, 0, 1, 1, 1, 1)
			self.quad:setViewport(x, y, shown * density, h, texture:getDimensions())
			lg.draw(texture, self.quad, fill_x, fill_y, 0, 1 / density, 1 / density)
		end
	end

	local marker_x = fill_x + shown
	if self.values.mania then
		-- stable hides the marker on the vertical mania bar
	elseif self.legacy then
		local danger = self.display < 0.2 and 3 or self.display < 0.5 and 2 or 1
		local ki = self.ki[danger]
		if ki then
			local width, height = TextureImage.dimensions(ki)
			TextureImage.draw(ki, marker_x, LEGACY_FILL_Y, 0, 1, 1, width / 2, height / 2)
		end
	elseif self.marker then
		local width, height = TextureImage.dimensions(self.marker)
		local mode, alpha_mode = lg.getBlendMode()
		lg.setBlendMode("add", "alphamultiply")
		TextureImage.draw(self.marker, marker_x, MARKER_Y, 0, 1, 1, width / 2, height / 2)
		lg.setBlendMode(mode, alpha_mode)
	end
	lg.pop()
end

return OsuHpBar
