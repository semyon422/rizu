local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local View = require("gui.View")

---@class ui.screens.remote_catalog.RemoteCatalogPreview : gui.View
---@operator call: ui.screens.remote_catalog.RemoteCatalogPreview
---@field image love.Image?
---@field text string
local RemoteCatalogPreview = View + {}

function RemoteCatalogPreview:new()
	View.new(self)
	self.image = nil
	self.text = "Select a chart with a background"
	self.font = Resources.getFont("regular", 16)
	self:setClip(true)
end

---@param image love.Image?
---@param text string?
function RemoteCatalogPreview:setImage(image, text)
	if self.image and self.image ~= image then
		self.image:release()
	end
	self.image = image
	self.text = text or ""
end

function RemoteCatalogPreview:unload()
	self:setImage(nil)
end

function RemoteCatalogPreview:draw()
	Painter.setColorTable(Colors.panel)
	love.graphics.rectangle("fill", 0, 0, self.width, self.height, 8, 8)
	local image = self.image
	if image then
		local image_width, image_height = image:getDimensions()
		local scale = math.min(self.width / image_width, self.height / image_height)
		local width, height = image_width * scale, image_height * scale
		Painter.setColorRgb(1, 1, 1)
		love.graphics.draw(image, (self.width - width) / 2, (self.height - height) / 2, 0, scale, scale)
		return
	end

	Painter.setColorTable(Colors.muted)
	love.graphics.setFont(self.font)
	love.graphics.printf(self.text, 20, (self.height - self.font:getHeight()) / 2, self.width - 40, "center")
end

return RemoteCatalogPreview
