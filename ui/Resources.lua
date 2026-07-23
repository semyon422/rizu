local ImageAtlasPacker = require("gui.packer.ImageAtlasPacker")
local Path = require("Path")

---@alias ui.FontName string
---@alias ui.FontSize 16 | 24 | 36 | 46 | 58 | 72 | 128

---@class ui.Resources
---@field atlas love.Image
---@field quads {[string]: love.Quad}
---@field dpi number
---@field fonts {[string]: love.Font}
local Resources = {}

Resources.ttf_font_fallback_path = "resources/fonts/NotoSansCJK-Regular.ttc"
Resources.ttf_font_paths = {
	regular = "resources/fonts/Rubik/Rubik-Regular.ttf",
	bold = "resources/fonts/Rubik/Rubik-Bold.ttf",
	cjk_regular = "resources/fonts/ZenMaruGothic/ZenMaruGothic-Regular.ttf",
	cjk_bold = "resources/fonts/ZenMaruGothic/ZenMaruGothic-Bold.ttf",
}

Resources.images_dir = "resources/ui.batch"
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

---@param name ui.FontName
---@param size ui.FontSize|integer
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

return Resources
