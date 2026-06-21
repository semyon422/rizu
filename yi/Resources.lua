local ImageAtlasPacker = require("yi.packer.ImageAtlasPacker")
local Path = require("Path")

---@alias yi.FontName string
---@alias yi.FontSize 16 | 24 | 36 | 46 | 58 | 72 | 128

---@class yi.Resources
---@field atlas love.Image
---@field quads {[string]: love.Quad}
---@field dpi number
---@field fonts {[string]: love.Font}
local Resources = {}

Resources.ttf_font_fallback_path = "resources/fonts/NotoSansCJK-Regular.ttc"
Resources.ttf_font_paths = {
	regular = "resources/fonts/ZenMaruGothic/ZenMaruGothic-Regular.ttf",
	bold = "resources/fonts/ZenMaruGothic/ZenMaruGothic-Bold.ttf",
}

Resources.sdf_font_path = "resources/fonts/Rubik/Rubik.fnt"
Resources.sdf_font_base_size = 48

Resources.images_dir = "resources/yi/batch"
Resources.fonts = {}
Resources.font_scale = 1
Resources.ui_scale = 1

function Resources.load()
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
	Resources.atlas = love.graphics.newImage(atlas_image_data)
	Resources.atlas:setWrap("clamp", "clamp")
	Resources.quads = quads

	setmetatable(Resources.quads, {
		__index = function(_self, k)
			assert(rawget(_self, k), k)
		end
	})
end

---@param v number
function Resources.setFontScale(v)
	Resources.font_scale = v
	Resources.fonts = {}
end

---@param v number
function Resources.setUIScale(v)
	Resources.ui_scale = v
end

---@return number
function Resources.getUIScale()
	return Resources.ui_scale or 1
end

---@param name yi.FontName
---@param size yi.FontSize|integer
---@return love.Font
function Resources.getFont(name, size)
	---@cast name string
	---@cast size integer
	local key = name .. tostring(size)

	if not Resources.fonts[key] then
		local path = Resources.ttf_font_paths[name]
		local object = love.graphics.newFont(path, size)
		local fallback = love.graphics.newFont(Resources.ttf_font_fallback_path, size)
		object:setFallbacks(fallback)
		Resources.fonts[key] = object
	end

	return Resources.fonts[key]
end

---@param name yi.FontName
---@param size yi.FontSize|integer
---@param scale? number
---@return love.Font
function Resources.getScaledFont(name, size, scale)
	scale = scale or Resources.font_scale or 1
	local scaled_size = math.max(1, math.floor(size * scale))
	return Resources.getFont(name, scaled_size)
end

---@return love.Font
function Resources.getSdfFont()
	if not Resources.sdf_font then
		Resources.sdf_font = love.graphics.newFont(Resources.sdf_font_path)
	end
	return Resources.sdf_font
end

return Resources
