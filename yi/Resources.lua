local class = require("class")
local ImageAtlasPacker = require("yi.packer.ImageAtlasPacker")
local Path = require("Path")

---@class yi.Resources
---@overload fun(): yi.Resources
---@field fonts {[string]: love.Font}
local Resources = class()

Resources.font_paths = {
	regular = "resources/fonts/MiSans-Regular.ttf",
	bold = "resources/fonts/MiSans-Bold.ttf",
	black = "resources/fonts/MiSans-Heavy.ttf",
	icons = "resources/fonts/lucide.ttf"
}

Resources.images_dir = "resources/yi"

---@alias yi.FontName "regular" | "bold" | "black" | "icons"
---@alias yi.FontSize 16 | 24 | 36 | 46 | 58 | 72 | 128

function Resources:new()
	self:setDpi(1)
end

function Resources:load()
	local t = {} ---@type {[string]: love.ImageData}
	local getDirItems = love.filesystem.getDirectoryItems

	for _, item in ipairs(getDirItems(Resources.images_dir)) do ---@diagnostic disable-line
		---@cast item string
		local path = Path(Resources.images_dir) .. item
		if path:getExtension() == "png" then
			local name = assert(path:getName(true))
			t[name] = love.image.newImageData(tostring(path))
		end
	end

	local packer = ImageAtlasPacker()
	local atlas_image_data, quads = packer:pack(t)
	self.atlas = love.graphics.newImage(atlas_image_data)
	self.quads = quads

	-- Hack to get the crisp scaling
	local x, y = self.quads.pixel:getViewport()
	self.quads.pixel:setViewport(x + 1, y + 1, 1, 1, self.atlas:getDimensions())
end

---@param dpi number
function Resources:setDpi(dpi)
	self.dpi = dpi
	self.fonts = {}
end

---@param name yi.FontName
---@param size yi.FontSize
---@return love.Font
function Resources:getFont(name, size)
	---@cast name string
	---@cast size integer
	local key = name .. tostring(size)

	if not self.fonts[key] then
		local path = self.font_paths[name]
		local object = love.graphics.newFont(path, size, "normal", self.dpi)
		self.fonts[key] = object
	end

	return self.fonts[key]
end

return Resources
