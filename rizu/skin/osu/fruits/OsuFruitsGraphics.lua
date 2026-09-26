local class = require("class")
local path_util = require("path_util")

local fruit_names = {"apple", "grapes", "orange", "pear", "bananas", "drop"}
local catcher_names = {"idle", "fail", "kiai"}

---@class rizu.skin.osu.fruits.Image
---@field image love.Image
---@field density number Pixel density (1 for normal assets, 0.5 for @2x assets).

---@class rizu.skin.osu.fruits.OsuFruitsGraphics.Images
---@field fruits {[string]: {image: rizu.skin.osu.fruits.Image?, overlay: rizu.skin.osu.fruits.Image?}}
---@field catcher {[string]: rizu.skin.osu.fruits.Image[]}

---@class rizu.skin.osu.fruits.OsuFruitsGraphics
---@operator call: rizu.skin.osu.fruits.OsuFruitsGraphics
---@field fs fs.IFilesystem?
---@field skin rizu.skin.OsuSkinDiscovery?
---@field images rizu.skin.osu.fruits.OsuFruitsGraphics.Images
---@field animation_framerate number?
---@field loaded boolean
local OsuFruitsGraphics = class()

---@param fs fs.IFilesystem?
---@param skin rizu.skin.OsuSkinDiscovery?
function OsuFruitsGraphics:new(fs, skin)
	self.fs = fs
	self.skin = skin
	self.images = {fruits = {}, catcher = {}}
	self.animation_framerate = nil
	self.loaded = false
end

---@param skin rizu.skin.OsuSkinDiscovery?
function OsuFruitsGraphics:setSkin(skin)
	if self.skin == skin then return end
	self:unload()
	self.skin = skin
end

---@param name string
---@return string?, number?
function OsuFruitsGraphics:findAsset(name)
	if not self.skin then return nil end
	local files = {}
	for _, path in ipairs(self.skin.files) do
		local file_name = path:match("([^/\\]+)$")
		if file_name and not path:find("/", 1, true) and not path:find(string.char(92), 1, true) then
			files[file_name:lower()] = path
		end
	end
	for _, density in ipairs({0.5, 1}) do
		local suffix = density == 0.5 and "@2x" or ""
		local path = files[(name .. suffix .. ".png"):lower()]
		if path then return path_util.join(self.skin.path, path), density end
	end
	if name == "fruit-drop-overlay" then
		for _, density in ipairs({0.5, 1}) do
			local suffix = density == 0.5 and "@2x" or ""
			local path = files[("fruit-droplet-overlay" .. suffix .. ".png"):lower()]
			if path then return path_util.join(self.skin.path, path), density end
		end
	end
end

---@param name string
---@return {path: string, density: number}[]
function OsuFruitsGraphics:findAnimationAssets(name)
	if not self.skin then return {} end
	local frames = {}
	for _, relative_path in ipairs(self.skin.files) do
		local file_name = relative_path:match("([^/\\]+)$")
		if file_name and not relative_path:find("/", 1, true) and not relative_path:find(string.char(92), 1, true) then
			file_name = file_name:lower()
			local suffix = file_name:sub(#name + 2)
			local index = file_name:sub(1, #name + 1) == name .. "-" and suffix:match("^([0-9]+)%.png$")
			local density = 1
			if not index and file_name:sub(1, #name + 1) == name .. "-" then
				index = suffix:match("^([0-9]+)@2x%.png$")
				density = 0.5
			end
			if index then
				local frame_index = tonumber(index)
				local frame = frames[frame_index]
				if not frame or density < frame.density then
					frames[frame_index] = {path = path_util.join(self.skin.path, relative_path), density = density}
				end
			end
		end
	end
	local indices = {}
	for index in pairs(frames) do indices[#indices + 1] = index end
	table.sort(indices)
	local result = {}
	if #indices == 0 then return result end
	local first = indices[1]
	for index = first, indices[#indices] do
		local frame = frames[index]
		if not frame then break end
		result[#result + 1] = frame
	end
	return result
end

---@param path string
---@return love.Image?
function OsuFruitsGraphics:loadImage(path)
	if not self.fs then return nil end
	local ok_data, content = pcall(self.fs.read, self.fs, path)
	if not ok_data or not content then return nil end
	local ok_file, file_data = pcall(love.filesystem.newFileData, content, path)
	if not ok_file then return nil end
	local ok_image, image = pcall(love.graphics.newImage, file_data)
	if not ok_image then return nil end
	if image:getWidth() <= 1 or image:getHeight() <= 1 then
		image:release()
		return nil
	end
	return image
end

---@param path string
---@param density number
---@return rizu.skin.osu.fruits.Image?
function OsuFruitsGraphics:loadSprite(path, density)
	local image = self:loadImage(path)
	if not image then return nil end
	image:setFilter("linear", "linear")
	return {image = image, density = density}
end

local function releaseImages(value, seen)
	if type(value) ~= "table" then return end
	if value.image then
		if not seen[value.image] then
			seen[value.image] = true
			value.image:release()
		end
		return
	end
	for _, child in pairs(value) do releaseImages(child, seen) end
end

function OsuFruitsGraphics:unload()
	releaseImages(self.images, {})
	self.images = {fruits = {}, catcher = {}}
	self.animation_framerate = nil
	self.loaded = false
end

function OsuFruitsGraphics:load()
	self:unload()
	self.loaded = true
	local skin = self.skin
	if not skin or not self.fs then return end

	local framerate = tonumber(skin.skin_ini.General.AnimationFramerate)
	if framerate and framerate > 0 then self.animation_framerate = framerate end

	for _, name in ipairs(fruit_names) do
		local image_path, density = self:findAsset("fruit-" .. name)
		local overlay_path, overlay_density = self:findAsset("fruit-" .. name .. "-overlay")
		local image = image_path and self:loadSprite(image_path, density)
		local overlay = overlay_path and self:loadSprite(overlay_path, overlay_density)
		if name == "drop" and not image then
			image_path, density = self:findAsset("fruit-droplet")
			image = image_path and self:loadSprite(image_path, density)
		end
		if name == "drop" and not overlay then
			overlay_path, overlay_density = self:findAsset("fruit-droplet-overlay")
			overlay = overlay_path and self:loadSprite(overlay_path, overlay_density)
		end
		self.images.fruits[name] = {image = image, overlay = overlay}
	end

	for _, state in ipairs(catcher_names) do
		local asset_name = "fruit-catcher-" .. state
		local paths = self:findAnimationAssets(asset_name)
		local frames = {}
		for _, frame in ipairs(paths) do
			local sprite = self:loadSprite(frame.path, frame.density)
			if sprite then frames[#frames + 1] = sprite end
		end
		if #frames == 0 then
			local path, density = self:findAsset(asset_name)
			if not path and state == "idle" then path, density = self:findAsset("fruit-ryuuta") end
			if path then
				local sprite = self:loadSprite(path, density)
				if sprite then frames[1] = sprite end
			end
		end
		self.images.catcher[state] = frames
	end

	-- Older skins only contain one catcher image, and use it for all states.
	local idle = self.images.catcher.idle
	for _, state in ipairs({"fail", "kiai"}) do
		if #self.images.catcher[state] == 0 then
			self.images.catcher[state] = idle
		end
	end
end

return OsuFruitsGraphics
