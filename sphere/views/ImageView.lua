local gfx_util = require("gfx_util")
local class = require("class")

---@class sphere.ImageView
---@operator call: sphere.ImageView
local ImageView = class()

function ImageView:load()
	local path = self.game.fileFinder:findFile(self.image)
	if path then
		local status, image = pcall(love.graphics.newImage, path)
		if status then
			self.imageObject = image
		end
	end
	if not self.imageObject then
		self.imageObject = gfx_util.newPixel()
	end
	self.imageWidth = self.imageObject:getWidth()
	self.imageHeight = self.imageObject:getHeight()
end

function ImageView:draw()
	local w, h = self.imageWidth, self.imageHeight

	local cw, ch = self.w, self.h
	local sx = cw and cw / w or self.sx or 1
	local sy = ch and ch / h or self.sy or 1
	local ox = (self.ox or 0) * w
	local oy = (self.oy or 0) * h

	local tf = gfx_util.transform(self.transform)
	love.graphics.replaceTransform(tf)

	if self.color then
		love.graphics.setColor(self.color)
	else
		love.graphics.setColor(1, 1, 1, 1)
	end
	love.graphics.draw(
		self.imageObject,
		self.x,
		self.y,
		self.r or 0,
		sx, sy, ox, oy
	)
end

return ImageView
