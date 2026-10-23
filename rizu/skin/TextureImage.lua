---@class rizu.skin.TextureImage
local TextureImage = {}

---@param image love.Image|rizu.skin.SkinTextures.Frame
---@return number, number
function TextureImage.dimensions(image)
	if image.texture then return image.width, image.height end
	if image.getDimensions then return image:getDimensions() end
	return image:getWidth(), image:getHeight()
end

---Draw a raw atlas region or standalone Image using logical-pixel transforms.
---@param image love.Image|rizu.skin.SkinTextures.Frame
---@param x number
---@param y number
---@param rotation number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
---@param batch rizu.skin.SpriteBatch?
function TextureImage.draw(image, x, y, rotation, sx, sy, ox, oy, batch)
	if image.texture then
		local density = image.density
		image.batch:add(image.texture, image.quad, x, y, rotation or 0,
			(sx or 1) / density, (sy or sx or 1) / density,
			(ox or 0) * density, (oy or 0) * density)
	else
		if batch then batch:flush() end
		love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or sx or 1, ox or 0, oy or 0)
	end
end

---@param graphics rizu.skin.SkinTextures
---@param x number
---@param y number
---@param width number
---@param height number
---@param group string? Atlas whose pixel is used, "playfield" by default.
function TextureImage.rectangle(graphics, x, y, width, height, group)
	local pixel = graphics.getAtlasFrame and graphics:getAtlasFrame(group or "playfield", "\0white")
	if pixel then
		TextureImage.draw(pixel, x, y, 0, width, height)
	else
		if graphics.batch then graphics.batch:flush() end
		love.graphics.rectangle("fill", x, y, width, height)
	end
end

---Draw without enqueueing, even if the image is an atlas region.
---The caller must flush its batch BEFORE changing graphics state.
---@param image love.Image|rizu.skin.SkinTextures.Frame
---@param x number
---@param y number
---@param rotation number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
function TextureImage.drawDirect(image, x, y, rotation, sx, sy, ox, oy)
	if image.texture then
		local density = image.density
		love.graphics.draw(image.texture, image.quad, x, y, rotation or 0,
			(sx or 1) / density, (sy or sx or 1) / density,
			(ox or 0) * density, (oy or 0) * density)
	else
		love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or sx or 1, ox or 0, oy or 0)
	end
end

return TextureImage
