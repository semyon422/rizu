local ImageAtlasPacker = require("gui.packer.ImageAtlasPacker")
local Path = require("Path")

---@alias ui.FontName string
---@alias ui.BMFontName string
---@alias ui.FontSize 16 | 24 | 36 | 46 | 58 | 72 | 128

---@class ui.Resources
---@field atlases love.Image[]
---@field sprites {[string]: gui.Sprite}
---@field dpi number
---@field fonts {[string]: love.Font}
---@field bmfonts {[string]: love.Font}
local Resources = {}

Resources.ttf_font_fallback_path = "resources/fonts/NotoSansCJK-Regular.ttc"
Resources.ttf_font_paths = {
	regular = "resources/fonts/Rubik/Rubik-Regular.ttf",
	medium = "resources/fonts/Rubik/Rubik-Medium.ttf",
	bold = "resources/fonts/Rubik/Rubik-Bold.ttf",
	cjk_regular = "resources/fonts/ZenMaruGothic/ZenMaruGothic-Regular.ttf",
	cjk_bold = "resources/fonts/ZenMaruGothic/ZenMaruGothic-Bold.ttf",
}
Resources.bmfont_paths = {
	outline_regular = "resources/fonts/Rubik/RubikRegularOutline.fnt"
}

Resources.images_dir = "resources/yi/batch"
Resources.fonts = {}
Resources.bmfonts = {}
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
	Resources.atlases, Resources.sprites = packer:pack(t)

	setmetatable(Resources.sprites, {
		__index = function(_self, key)
			error(("sprite `%s` does not exist"):format(key), 2)
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
		local path = assert(Resources.ttf_font_paths[name], ("TTF font `%s` does not exist"):format(name))
		local object = love.graphics.newFont(path, size)
		local fallback = love.graphics.newFont(Resources.ttf_font_fallback_path, size)
		object:setFallbacks(fallback)
		Resources.fonts[key] = object
	end

	return Resources.fonts[key]
end

---@param name ui.BMFontName
---@return love.Font
function Resources.getBMFont(name)
	if not Resources.bmfonts[name] then
		local path = assert(Resources.bmfont_paths[name], ("BMFont `%s` does not exist"):format(name))
		Resources.bmfonts[name] = love.graphics.newFont(path)
	end
	return Resources.bmfonts[name]
end

return Resources
