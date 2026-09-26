---@class rizu.skin.osu.aim.OsuSpriteRenderer
local OsuSpriteRenderer = {}

---@param sprite rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
---@return boolean
function OsuSpriteRenderer.isRenderable(sprite)
	return not not (sprite and sprite.image:getWidth() > 1 and sprite.image:getHeight() > 1)
end

---@param sprite rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
---@return number
function OsuSpriteRenderer.getWidth(sprite)
	if not sprite or not OsuSpriteRenderer.isRenderable(sprite) then return 0 end
	return sprite.image:getWidth() * sprite.density
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
	local image_width, image_height = image:getDimensions()
	local scale = width / image_width
	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.draw(image, x, y, rotation or 0, scale, scale, image_width / 2, image_height / 2)
end

return OsuSpriteRenderer
