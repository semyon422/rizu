local class = require("class")
local path_util = require("path_util")

local asset_names = {
	taikohitcircle = "taikohitcircle",
	taikohitcircleoverlay = "taikohitcircleoverlay",
	taikobigcircle = "taikobigcircle",
	taikobigcircleoverlay = "taikobigcircleoverlay",
	bar_left = "taiko-bar-left",
	bar_right = "taiko-bar-right",
	drum_inner = "taiko-drum-inner",
	drum_outer = "taiko-drum-outer",
	roll_middle = "taiko-roll-middle",
	roll_end = "taiko-roll-end",
}

---@class rizu.skin.osu.taiko.OsuTaikoSkinGraphics
---@operator call: rizu.skin.osu.taiko.OsuTaikoSkinGraphics
---@field fs fs.IFilesystem?
---@field skin rizu.skin.OsuSkinDiscovery?
---@field images {[string]: love.Image}
local OsuTaikoSkinGraphics = class()

---@param fs fs.IFilesystem?
---@param skin rizu.skin.OsuSkinDiscovery?
function OsuTaikoSkinGraphics:new(fs, skin)
	self.fs = fs
	self.skin = skin
	self.images = {}
	self.loaded = false
end

---@param skin rizu.skin.OsuSkinDiscovery?
function OsuTaikoSkinGraphics:setSkin(skin)
	if self.skin == skin then return end
	self:unload()
	self.skin = skin
end

---@param name string
---@return string?
function OsuTaikoSkinGraphics:findAsset(name)
	local skin = self.skin
	local base_name = asset_names[name]
	if not skin or not base_name then return end

	local files = {}
	for _, relative_path in ipairs(skin.files) do
		local file_name = relative_path:match("([^/]+)$")
		if file_name and not relative_path:find("/", 1, true) then
			files[file_name:lower()] = relative_path
		end
	end
	for _, suffix in ipairs({"@2x", ""}) do
		local relative_path = files[(base_name .. suffix .. ".png"):lower()]
		if relative_path then return path_util.join(skin.path, relative_path) end
	end
end

function OsuTaikoSkinGraphics:unload()
	for _, image in pairs(self.images) do image:release() end
	self.images = {}
	self.loaded = false
end

---@param path string
---@return love.Image?
function OsuTaikoSkinGraphics:loadImage(path)
	local fs = self.fs
	if not fs then return end
	---@type boolean, string?
	local ok_read, content = pcall(fs.read, fs, path)
	if not ok_read or type(content) ~= "string" then return end
	local ok_data, file_data = pcall(love.filesystem.newFileData, content, path)
	if not ok_data then return end
	local ok_image, image = pcall(love.graphics.newImage, file_data)
	if not ok_image then return end
	if image:getWidth() <= 1 or image:getHeight() <= 1 then
		image:release()
		return
	end
	return image
end

function OsuTaikoSkinGraphics:load()
	self:unload()
	self.loaded = true
	if not self.skin or not self.fs then return end
	for name in pairs(asset_names) do
		local path = self:findAsset(name)
		if path then
			local image = self:loadImage(path)
			if image then self.images[name] = image end
		end
	end
end

return OsuTaikoSkinGraphics
