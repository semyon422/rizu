local class = require("class")
local ImageAtlasPacker = require("yi.packer.ImageAtlasPacker")
local Path = require("aqua.Path")

---@class yi.Resources
---@overload fun(): yi.Resources
---@field fonts {[string]: love.Font}
local Resources = class()

Resources.font_paths = {
	regular = "resources/fonts/Roboto/Roboto-Regular.ttf",
	bold = "resources/fonts/Roboto/Roboto-Bold.ttf",
}

Resources.images_dir = "resources/yi/batch"

---@alias yi.FontName string
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

	local pixel = love.image.newImageData(1, 1)
	pixel:setPixel(0, 0, 1, 1, 1, 1)
	t.pixel = pixel

	local packer = ImageAtlasPacker()
	local atlas_image_data, quads = packer:pack(t)
	self.atlas = love.graphics.newImage(atlas_image_data)
	self.atlas:setWrap("clamp", "clamp")
	self.quads = quads
end

---@param dpi number
function Resources:setDpi(dpi)
	self.dpi = dpi
	self.fonts = {}
end

---@param name yi.FontName
---@param size yi.FontSize|integer
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

---@param name yi.FontName
---@param size yi.FontSize|integer
---@param ui_scale number?
---@return love.Font
---@return integer
function Resources:getScaledFont(name, size, ui_scale)
	ui_scale = ui_scale or 1
	local scaled_size = math.max(1, math.floor(size * ui_scale))
	return self:getFont(name, scaled_size), scaled_size
end

return Resources
