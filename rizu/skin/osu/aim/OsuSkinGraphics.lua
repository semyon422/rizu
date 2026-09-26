local class = require("class")
local path_util = require("path_util")

local asset_names = {
	hitcircle = "hitcircle",
	hitcircleoverlay = "hitcircleoverlay",
	approachcircle = "approachcircle",
	sliderstartcircle = "sliderstartcircle",
	sliderstartcircleoverlay = "sliderstartcircleoverlay",
	reversearrow = "reversearrow",
	sliderendcircle = "sliderendcircle",
	sliderendcircleoverlay = "sliderendcircleoverlay",
	sliderb = "sliderb",
	sliderfollowcircle = "sliderfollowcircle",
	sliderscorepoint = "sliderscorepoint",
}

---@class rizu.skin.osu.aim.OsuSkinGraphics.Sprite
---@field image love.Image
---@field density number Pixel-to-logical scale (1 for normal assets, 0.5 for @2x assets).

---@class rizu.skin.osu.aim.OsuSkinGraphics.Sprites
---@field [string] rizu.skin.osu.aim.OsuSkinGraphics.Sprite|rizu.skin.osu.aim.OsuSkinGraphics.Sprite[]?
---@field hitcircle rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
---@field hitcircleoverlay rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
---@field approachcircle rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
---@field sliderstartcircle rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
---@field sliderstartcircleoverlay rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
---@field reversearrow rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
---@field sliderendcircle rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
---@field sliderendcircleoverlay rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
---@field sliderb rizu.skin.osu.aim.OsuSkinGraphics.Sprite[]?
---@field sliderfollowcircle rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
---@field sliderscorepoint rizu.skin.osu.aim.OsuSkinGraphics.Sprite?

---@class rizu.skin.osu.aim.OsuSkinGraphics.Asset
---@field path string
---@field density number

---@class rizu.skin.osu.aim.OsuSkinGraphics
---@operator call: rizu.skin.osu.aim.OsuSkinGraphics
---@field fs fs.IFilesystem?
---@field skin rizu.skin.OsuSkinDiscovery?
---@field images rizu.skin.osu.aim.OsuSkinGraphics.Sprites
---@field slider_ball_flip boolean
---@field animation_framerate number?
---@field slider_ball_frames rizu.skin.osu.aim.OsuSkinGraphics.Sprite[]
---@field loaded boolean
---@field files {[string]: string}
local OsuSkinGraphics = class()

---@param fs fs.IFilesystem?
---@param skin rizu.skin.OsuSkinDiscovery?
function OsuSkinGraphics:new(fs, skin)
	self.fs = fs
	self.skin = skin
	self.images = {}
	self.slider_ball_frames = {}
	self.animation_framerate = nil
	self.slider_ball_flip = false
	self.loaded = false
	self.files = {}
	self:indexSkinFiles()
end

function OsuSkinGraphics:indexSkinFiles()
	self.files = {}
	if not self.skin then return end
	for _, path in ipairs(self.skin.files) do
		-- osu! skins resolve gameplay sprites from the skin root, not subfolders.
		if not path:find("[/\\]") then
			self.files[path:lower()] = path
		end
	end
end

---@param skin rizu.skin.OsuSkinDiscovery?
function OsuSkinGraphics:setSkin(skin)
	if self.skin == skin then return end
	self:unload()
	self.skin = skin
	self:indexSkinFiles()
end

---@param name string
---@return string?, number?
function OsuSkinGraphics:findAsset(name)
	local base_name = asset_names[name]
	if not self.skin or not base_name then return end

	for _, asset in ipairs({{"@2x", 0.5}, {"", 1}}) do
		local suffix, density = asset[1], asset[2]
		local relative_path = self.files[(base_name .. suffix .. ".png"):lower()]
		if relative_path then
			return path_util.join(self.skin.path, relative_path), density
		end
	end
end

---@return rizu.skin.osu.aim.OsuSkinGraphics.Asset[]
function OsuSkinGraphics:findSliderBallAssets()
	---@type {[integer]: rizu.skin.osu.aim.OsuSkinGraphics.Asset}
	local numbered_frames = {}
	for file_name, relative_path in pairs(self.files) do
		local high_index, low_index = file_name:match("^sliderb(%d+)@2x%.png$"), file_name:match("^sliderb(%d+)%.png$")
		local index, density = tonumber(high_index or low_index), high_index and 0.5 or 1
		if index then
			local frame = numbered_frames[index]
			if not frame or density < frame.density then
				numbered_frames[index] = {
					path = path_util.join(self.skin.path, relative_path),
					density = density,
				}
			end
		end
	end

	-- osu! only treats numbered slider balls as an animation starting at frame 0,
	-- and stops at the first missing frame.
	---@type rizu.skin.osu.aim.OsuSkinGraphics.Asset[]
	local frames = {}
	local index = 0
	while numbered_frames[index] do
		frames[#frames + 1] = numbered_frames[index]
		index = index + 1
	end
	if #frames > 0 then return frames end

	local high_density = self.files["sliderb@2x.png"]
	local path = high_density or self.files["sliderb.png"]
	if path then
		return {{
			path = path_util.join(self.skin.path, path),
			density = high_density and 0.5 or 1,
		}}
	end
	return {}
end

---@param name string
---@param path string
---@param density number
---@return rizu.skin.osu.aim.OsuSkinGraphics.Sprite?
function OsuSkinGraphics:loadImage(name, path, density)
	local ok_data, content = pcall(self.fs.read, self.fs, path)
	if not ok_data then
		print(("could not read osu! skin asset %s: %s"):format(path, tostring(content)))
		return
	end
	if not content then return end
	local file_data_ok, file_data = pcall(love.filesystem.newFileData, content, path)
	if not file_data_ok then
		print(("could not create osu! skin asset data %s: %s"):format(path, tostring(file_data)))
		return
	end
	local image_ok, image = pcall(love.graphics.newImage, file_data)
	if not image_ok then
		print(("could not load osu! skin asset %s: %s"):format(path, tostring(image)))
		return
	end
	if image:getWidth() <= 1 or image:getHeight() <= 1 then
		image:release()
		return
	end
	if name == "sliderfollowcircle" then
		image:setFilter("linear", "linear")
	end
	return {image = image, density = density}
end

---@param sprite rizu.skin.osu.aim.OsuSkinGraphics.Sprite
local function releaseSprite(sprite)
	sprite.image:release()
end

function OsuSkinGraphics:unload()
	for name in pairs(asset_names) do
		if name ~= "sliderb" then
			local sprite = self.images[name]
			if sprite then releaseSprite(sprite) end
		end
	end
	for _, sprite in ipairs(self.slider_ball_frames) do releaseSprite(sprite) end
	self.slider_ball_frames = {}
	self.images = {}
	self.animation_framerate = nil
	self.slider_ball_flip = false
	self.loaded = false
end

function OsuSkinGraphics:load()
	self:unload()
	self.loaded = true
	if not self.skin or not self.fs then return end

	local general = self.skin.skin_ini.General
	local flip_value = general.SliderBallFlip or general.SliderBallDontRotate
	self.slider_ball_flip = flip_value == "true" or tonumber(flip_value) == 1
	local animation_framerate = tonumber(general.AnimationFramerate)
	if animation_framerate and animation_framerate > 0 then
		self.animation_framerate = animation_framerate
	end

	for _, asset in ipairs(self:findSliderBallAssets()) do
		local sprite = self:loadImage("sliderb", asset.path, asset.density)
		if sprite then self.slider_ball_frames[#self.slider_ball_frames + 1] = sprite end
	end
	if #self.slider_ball_frames > 0 then self.images.sliderb = self.slider_ball_frames end

	for name in pairs(asset_names) do
		if name ~= "sliderb" then
			local path, density = self:findAsset(name)
			if path then self.images[name] = self:loadImage(name, path, density or 1) end
		end
	end

end

return OsuSkinGraphics
