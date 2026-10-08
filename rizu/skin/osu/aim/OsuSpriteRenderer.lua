local OsuImage = require("rizu.skin.osu.OsuImage")

---@class rizu.skin.osu.aim.OsuSpriteRenderer
local OsuSpriteRenderer = {}

---@param sprite rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
---@return boolean
function OsuSpriteRenderer.isRenderable(sprite)
	if not sprite then return false end
	local width, height = OsuImage.dimensions(sprite.image)
	return width > 1 and height > 1
end

---@param sprite rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
---@return number
function OsuSpriteRenderer.getWidth(sprite)
	if not sprite or not OsuSpriteRenderer.isRenderable(sprite) then return 0 end
	return OsuImage.dimensions(sprite.image) * sprite.density
end

---@param sprite rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
---@param x number
---@param y number
---@param width number
---@param alpha number
---@param rotation number?
function OsuSpriteRenderer.draw(sprite, x, y, width, alpha, rotation)
	if not OsuSpriteRenderer.isRenderable(sprite) or width <= 0 then return end
	---@cast sprite rizu.skin.osu.aim.OsuSkinGraphics.Sprite
	local image = sprite.image
	local image_width, image_height = OsuImage.dimensions(image)
	local scale = width / image_width
	love.graphics.setColor(1, 1, 1, alpha)
	OsuImage.draw(image, x, y, rotation or 0, scale, scale, image_width / 2, image_height / 2)
end

return OsuSpriteRenderer
