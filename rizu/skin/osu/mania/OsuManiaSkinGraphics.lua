local class = require("class")
local path_util = require("path_util")

---@class rizu.skin.osu.mania.OsuManiaSkinGraphics
---@operator call: rizu.skin.osu.mania.OsuManiaSkinGraphics
---@field fs fs.IFilesystem?
---@field skin rizu.skin.OsuSkinDiscovery?
---@field images {[string]: love.Image|false}
---@field file_map {[string]: string} Lowercase asset path to full filesystem path.
---@field frame_cache {[string]: love.Image[]}
---@field animation_cache {[string]: love.Image[]}
---@field image_density {[love.Image]: number}
---@field loaded boolean
---@field fallback_directory string?
local OsuManiaSkinGraphics = class()

---@param fs fs.IFilesystem?
---@param skin rizu.skin.OsuSkinDiscovery?
function OsuManiaSkinGraphics:new(fs, skin)
	self.fs = fs
	self.skin = nil
	self.images = {}
	self.file_map = {}
	self.frame_cache = {}
	self.animation_cache = {}
	self.image_density = {}
	self.loaded = false
	self.fallback_directory = nil
	self:setSkin(skin)
end

function OsuManiaSkinGraphics:indexFiles()
	self.file_map = {}
	for _, relative_path in ipairs(self.skin and self.skin.files or {}) do
		local normalized = relative_path:gsub("\\", "/")
		self.file_map[normalized:lower()] = path_util.join(self.skin.path, relative_path)
	end
	if self.fallback_directory then
		local ok, file_names = pcall(love.filesystem.getDirectoryItems, self.fallback_directory)
		if ok then
			for _, file_name in ipairs(file_names) do
				local asset = self.fallback_directory .. "/" .. file_name
				self.file_map[file_name:lower()] = self.file_map[file_name:lower()] or asset
			end
		end
	end
end

---@param skin rizu.skin.OsuSkinDiscovery?
function OsuManiaSkinGraphics:setSkin(skin)
	if self.skin == skin and (self.loaded or next(self.file_map)) then return end
	if self.loaded or next(self.images) then self:unload() end
	self.skin = skin
	self.frame_cache = {}
	self.animation_cache = {}
	self:indexFiles()
end

function OsuManiaSkinGraphics:setFallbackDirectory(directory)
	if self.fallback_directory == directory then return end
	if self.loaded or next(self.images) then self:unload() end
	self.fallback_directory = directory
	self.frame_cache = {}
	self.animation_cache = {}
	self:indexFiles()
end

---@param name string
---@return string?
function OsuManiaSkinGraphics:findAsset(name)
	if type(name) ~= "string" or name == "" then return nil end
	name = name:gsub("\\", "/"):gsub("^/+", ""):lower()
	local stem = name:gsub("%.png$", "")
	for _, candidate in ipairs({stem .. "@2x.png", stem .. ".png"}) do
		local path = self.file_map[candidate:lower()]
		if path then return path end
	end
end

---@param base string
---@return {index: integer, path: string}[]
function OsuManiaSkinGraphics:findAnimationAssets(base)
	if type(base) ~= "string" or base == "" then return {} end
	base = base:gsub("\\", "/"):gsub("^/+", ""):gsub("%.png$", ""):lower()
	local directory, stem = base:match("^(.*[/])([^/]+)$")
	directory = directory or ""
	stem = stem or base
	local escaped_stem = stem:gsub("([^%w])", "%%%1")
	local found = {}
	for normalized_path, path in pairs(self.file_map) do
		local file_directory, file_name = normalized_path:match("^(.*[/])([^/]+)$")
		file_directory = file_directory or ""
		file_name = file_name or normalized_path
		if file_directory == directory then
			local index = file_name:match("^" .. escaped_stem .. "%-([0-9]+)@2x%.png$")
				or file_name:match("^" .. escaped_stem .. "%-([0-9]+)%.png$")
			if index then
				index = tonumber(index)
				local frame = found[index]
				local high_density = file_name:find("@2x.png", 1, true) ~= nil
				if not frame or high_density then
					found[index] = {index = index, path = path, high_density = high_density}
				end
			end
		end
	end

	local indices = {}
	for index in pairs(found) do indices[#indices + 1] = index end
	table.sort(indices)
	local result = {}
	if #indices == 0 then return result end
	local index = found[0] and 0 or 1
	while found[index] do
		result[#result + 1] = found[index]
		index = index + 1
	end
	return result
end

---@param path string
---@return love.Image?
function OsuManiaSkinGraphics:loadImage(path)
	local cached = self.images[path]
	if cached ~= nil then return cached or nil end
	if self.fallback_directory and path:sub(1, #self.fallback_directory + 1) == self.fallback_directory .. "/" then
		local ok_image, image = pcall(love.graphics.newImage, path)
		if not ok_image or image:getWidth() <= 0 or image:getHeight() <= 0 then
			if ok_image then image:release() end
			self.images[path] = false
			return nil
		end
		self.images[path] = image
		self.image_density[image] = path:lower():match("@2x%.png$") and 2 or 1
		return image
	end
	if not self.fs then return nil end

	local ok_read, content = pcall(self.fs.read, self.fs, path)
	if not ok_read or not content then
		self.images[path] = false
		return nil
	end
	local ok_data, file_data = pcall(love.filesystem.newFileData, content, path)
	if not ok_data then
		self.images[path] = false
		return nil
	end
	local ok_image, image = pcall(love.graphics.newImage, file_data)
	if not ok_image or image:getWidth() <= 0 or image:getHeight() <= 0 then
		if ok_image then image:release() end
		self.images[path] = false
		return nil
	end
	self.images[path] = image
	self.image_density[image] = path:lower():match("@2x%.png$") and 2 or 1
	return image
end

---@param image love.Image
---@return number
function OsuManiaSkinGraphics:getImageDensity(image)
	return self.image_density[image] or 1
end

---@param image_name string?
---@param fallback_name string?
---@return love.Image[]
function OsuManiaSkinGraphics:getFrames(image_name, fallback_name)
	local key = tostring(image_name or "") .. "\0" .. tostring(fallback_name or "")
	local cached = self.frame_cache[key]
	if cached then return cached end
	local frames = {}
	local function load_name(name)
		if not name or name == "" then return end
		local path = self:findAsset(name)
		local image = path and self:loadImage(path)
		if image then frames[1] = image end
	end
	load_name(image_name)
	if #frames == 0 and fallback_name ~= image_name then load_name(fallback_name) end
	self.frame_cache[key] = frames
	return frames
end

---@param image_name string?
---@param fallback_name string?
---@return love.Image[]
function OsuManiaSkinGraphics:getAnimationFrames(image_name, fallback_name)
	local key = tostring(image_name or "") .. "\0" .. tostring(fallback_name or "")
	local cached = self.animation_cache[key]
	if cached then return cached end
	local function load_animation(name)
		if name == nil then return {} end
		---@cast name string
		local discovered = self:findAnimationAssets(name)
		local frames = {}
		for _, asset in ipairs(discovered) do
			local image = self:loadImage(asset.path)
			if image then frames[#frames + 1] = image end
		end
		return frames
	end
	local frames = load_animation(image_name)
	if #frames == 0 and image_name then
		local image = self:getFrames(image_name, nil)[1]
		if image then frames[1] = image end
	end
	if #frames == 0 and fallback_name ~= image_name then frames = load_animation(fallback_name) end
	if #frames == 0 then
		local image = self:getFrames(nil, fallback_name)[1]
		if image then frames[1] = image end
	end
	self.animation_cache[key] = frames
	return frames
end

function OsuManiaSkinGraphics:load(assets)
	self.loaded = true
	for _, asset in ipairs(assets or {}) do
		if asset.animation then
			self:getAnimationFrames(asset.name, asset.fallback)
		else
			self:getFrames(asset.name, asset.fallback)
		end
	end
end

function OsuManiaSkinGraphics:unload()
	for _, image in pairs(self.images) do
		if image then image:release() end
	end
	self.images = {}
	self.frame_cache = {}
	self.animation_cache = {}
	self.image_density = {}
	self.loaded = false
	self:indexFiles()
end

return OsuManiaSkinGraphics
