local HudElement = require("rizu.skin.hud.HudElement")
local TextureImage = require("rizu.skin.TextureImage")

local lg = love.graphics

local SIZE = 24
local RADIUS = 10
local SPRITE_SCALE = 480 / 768
local BEFORE_START_COLOR = {0.78, 1, 0.18, 0.6}
local PLAYING_COLOR = {1, 1, 1, 0.6}

---A pie filling up over the play, with an optional texture over it.
---@class rizu.skin.hud.elements.Progress : rizu.skin.hud.HudElement
---@operator call: rizu.skin.hud.elements.Progress
---@field progress number -1..1, negative before the first note.
---@field image rizu.skin.SkinTextures.Image?
local Progress = HudElement + {}

Progress.label = "Progress"
Progress.fields = {
	{key = "texture", label = "Texture", type = "texture", default = ""},
}

---@param values {[string]: any}?
---@param textures rizu.skin.SkinTextures
function Progress:new(values, textures)
	self.progress = 0
	HudElement.new(self, values, textures)
	self.width, self.height = SIZE, SIZE
end

---@return rizu.skin.SkinTextures.Asset[]
function Progress:getAssets()
	return {{name = self.values.texture --[[@as string]], group = HudElement.group}}
end

---@param context rizu.api.GameApi
function Progress:load(context)
	HudElement.load(self, context)
	self.image = self:getTexture(self.values.texture --[[@as string]])
end

---@param context rizu.api.GameApi?
function Progress:unload(context)
	self.image = nil
	HudElement.unload(self, context)
end

---@param _ number
---@param context rizu.api.GameApi
function Progress:update(_, context)
	local progress = tonumber(context.gameplay:getProgress()) or 0
	self.progress = progress == progress and math.max(-1, math.min(1, progress)) or 0
end

function Progress:draw()
	local cx, cy = SIZE / 2, SIZE / 2
	local mode, alpha_mode = lg.getBlendMode()
	lg.setBlendMode("add", "alphamultiply")
	lg.setColor(1, 1, 1, 0.16)
	lg.circle("line", cx, cy, RADIUS)
	if self.progress ~= 0 then
		HudElement.setColor(self.progress < 0 and BEFORE_START_COLOR or PLAYING_COLOR)
		local angle = math.abs(self.progress) * math.pi * 2
		lg.arc("fill", "pie", cx, cy, RADIUS, -math.pi / 2, -math.pi / 2 + angle, math.max(2, math.ceil(angle * 10)))
	end
	local image = self.image
	if image then
		local width, height = TextureImage.dimensions(image)
		lg.setColor(1, 1, 1, 1)
		TextureImage.draw(image, cx, cy, 0, SPRITE_SCALE, SPRITE_SCALE, width / 2, height / 2)
	end
	lg.setBlendMode(mode, alpha_mode)
end

return Progress
