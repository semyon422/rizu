local OsuImage = require("rizu.skin.osu.OsuImage")

---@class rizu.skin.osu.aim.OsuSpriteRenderer
local OsuSpriteRenderer = {}

---@param sprite rizu.skin.osu.OsuSkinGraphics.Image?
---@return boolean
function OsuSpriteRenderer.isRenderable(sprite)
	if not sprite then return false end
	local width, height = OsuImage.dimensions(sprite)
	return width > 1 and height > 1
end

---@param sprite rizu.skin.osu.OsuSkinGraphics.Image?
---@return number
function OsuSpriteRenderer.getWidth(sprite)
	if not sprite or not OsuSpriteRenderer.isRenderable(sprite) then return 0 end
	return (OsuImage.dimensions(sprite))
end

---Queued sprites must reach the screen before a primitive is drawn over them.
---@param sprites rizu.skin.osu.aim.OsuAimSprites?
function OsuSpriteRenderer.flush(sprites)
	if sprites and sprites.batch then sprites.batch:flush() end
end

---@param sprite rizu.skin.osu.OsuSkinGraphics.Image?
---@param x number
---@param y number
---@param width number
---@param alpha number
---@param rotation number?
---@param color number[]? RGB tint
function OsuSpriteRenderer.draw(sprite, x, y, width, alpha, rotation, color)
	if not OsuSpriteRenderer.isRenderable(sprite) or width <= 0 then return end
	---@cast sprite rizu.skin.osu.OsuSkinGraphics.Image
	local image_width, image_height = OsuImage.dimensions(sprite)
	local scale = width / image_width
	if color then
		love.graphics.setColor(color[1], color[2], color[3], alpha)
	else
		love.graphics.setColor(1, 1, 1, alpha)
	end
	OsuImage.draw(sprite, x, y, rotation or 0, scale, scale, image_width / 2, image_height / 2)
end

return OsuSpriteRenderer
