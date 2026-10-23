local HudElement = require("rizu.skin.hud.HudElement")
local TextureImage = require("rizu.skin.TextureImage")

---Any texture of the skin.
---@class rizu.skin.hud.elements.Sprite : rizu.skin.hud.HudElement
---@operator call: rizu.skin.hud.elements.Sprite
---@field image rizu.skin.SkinTextures.Image?
local Sprite = HudElement + {}

Sprite.label = "Sprite"
Sprite.fields = {
	{key = "texture", label = "Texture", type = "texture", default = ""},
	{key = "color", label = "Color", type = "color", default = {1, 1, 1, 1}},
}

---@return rizu.skin.SkinTextures.Asset[]
function Sprite:getAssets()
	return {{name = self.values.texture --[[@as string]], group = HudElement.group}}
end

---@param context rizu.api.GameApi
function Sprite:load(context)
	HudElement.load(self, context)
	self.image = self:getTexture(self.values.texture --[[@as string]])
	if self.image then self.width, self.height = TextureImage.dimensions(self.image) end
end

---@param context rizu.api.GameApi?
function Sprite:unload(context)
	self.image = nil
	HudElement.unload(self, context)
end

function Sprite:draw()
	if not self.image then return end
	HudElement.setColor(self.values.color --[[@as number[] ]])
	TextureImage.draw(self.image, 0, 0)
end

return Sprite
