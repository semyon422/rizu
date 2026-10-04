---@class rizu.skin.osu.mania.OsuManiaImage
local OsuManiaImage = {}

---@param image love.Image|rizu.skin.osu.mania.OsuManiaSkinGraphics.Frame
---@return number, number
function OsuManiaImage.dimensions(image)
	if image.texture then return image.width, image.height end
	if image.getDimensions then return image:getDimensions() end
	return image:getWidth(), image:getHeight()
end

---Draw a raw atlas region or standalone Image using logical-pixel transforms.
---@param image love.Image|rizu.skin.osu.mania.OsuManiaSkinGraphics.Frame
---@param x number
---@param y number
---@param rotation number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
---@param batch rizu.skin.osu.mania.OsuManiaBatch?
function OsuManiaImage.draw(image, x, y, rotation, sx, sy, ox, oy, batch)
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

---@param graphics rizu.skin.osu.mania.OsuManiaSkinGraphics
---@param x number
---@param y number
---@param width number
---@param height number
function OsuManiaImage.rectangle(graphics, x, y, width, height)
	local pixel = graphics.getAtlasFrame and graphics:getAtlasFrame("playfield", "\0white")
	if pixel then
		OsuManiaImage.draw(pixel, x, y, 0, width, height)
	else
		if graphics.batch then graphics.batch:flush() end
		love.graphics.rectangle("fill", x, y, width, height)
	end
end

return OsuManiaImage
