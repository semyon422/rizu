local class = require("class")
local path_util = require("path_util")
local ZipFilesystem = require("fs.ZipFilesystem")

---@type {[string]: fs.ZipFilesystem}
local archive_cache = {}

---@param resource any
local function release_resource(resource)
	if resource and resource.release then
		pcall(resource.release, resource)
	end
end

---@return number?
local function get_texture_size()
	local ok_limits, limits = pcall(love.graphics.getSystemLimits)
	local texture_size = ok_limits and limits and tonumber(limits.texturesize)
	if texture_size and texture_size > 0 then return texture_size end
end

---@param image_data love.ImageData
---@return love.ImageData
local function limit_image_data(image_data)
	local texture_size = get_texture_size()
	if not texture_size then return image_data end

	local width, height = image_data:getDimensions()
	if width <= texture_size and height <= texture_size then return image_data end

	local limited = love.image.newImageData(math.min(width, texture_size), math.min(height, texture_size))
	limited:paste(image_data, 0, 0, 0, 0, limited:getWidth(), limited:getHeight())
	return limited
end

---@param image any
---@return number?, number?
local function get_image_dimensions(image)
	if image.getDimensions then
		local ok, width, height = pcall(image.getDimensions, image)
		if ok then return width, height end
	end
	if image.getWidth and image.getHeight then
		local ok_width, width = pcall(image.getWidth, image)
		local ok_height, height = pcall(image.getHeight, image)
		if ok_width and ok_height then return width, height end
	end
end

---@param source any
---@return love.Image?
local function create_image(source)
	---@param image any
	---@return boolean
	local function is_valid(image)
		if not image then return false end
		local width, height = get_image_dimensions(image)
		if width and height and width > 0 and height > 0 then return true end
		release_resource(image)
		return false
	end

	-- osu! creates the GPU texture with each dimension capped at the maximum
	-- supported texture size, copying the bitmap from its top-left corner.
	-- Decode before uploading so a driver that accepts the original oversized
	-- image still produces the same texture as osu!.
	local ok_data, image_data = pcall(love.image.newImageData, source)
	if ok_data then
		local ok_limited, limited = pcall(limit_image_data, image_data)
		if ok_limited then
			local ok_limited_image, limited_image = pcall(love.graphics.newImage, limited)
			release_resource(limited)
			if limited ~= image_data then release_resource(image_data) end
			if ok_limited_image and is_valid(limited_image) then return limited_image end
		else
			release_resource(image_data)
		end
	end

	-- Keep the direct path as a fallback for decoders that only LÖVE can
	-- consume directly (and for non-image files presented by fake filesystems).
	local ok_image, image = pcall(love.graphics.newImage, source)
	if ok_image and is_valid(image) then return image end
	return nil
end

---@class rizu.skin.osu.mania.OsuManiaSkinGraphics
---@operator call: rizu.skin.osu.mania.OsuManiaSkinGraphics
---@field fs fs.IFilesystem?
---@field skin rizu.skin.OsuSkinDiscovery?
---@field images {[string]: love.Image|false}
---@field file_map {[string]: string} Lowercase selected skin asset path to full filesystem path.
---@field fallback_file_map {[string]: string}
---@field fallback_archive string?
---@field fallback_fs fs.ZipFilesystem?
---@field frame_cache {[string]: love.Image[]}
---@field animation_cache {[string]: love.Image[]}
---@field image_density {[love.Image]: number}
---@field loaded boolean
---@field generation integer
---@field fallback_directory string?
local OsuManiaSkinGraphics = class()

---@param fs fs.IFilesystem?
---@param skin rizu.skin.OsuSkinDiscovery?
function OsuManiaSkinGraphics:new(fs, skin)
	self.fs = fs
	self.skin = nil
	self.images = {}
	self.file_map = {}
	self.fallback_file_map = {}
	self.frame_cache = {}
	self.animation_cache = {}
	self.image_density = {}
	self.loaded = false
	self.generation = 0
	self.fallback_directory = nil
	self:setSkin(skin)
end

function OsuManiaSkinGraphics:indexFiles()
	self.file_map = {}
	self.fallback_file_map = {}
	for _, relative_path in ipairs(self.skin and self.skin.files or {}) do
		local normalized = relative_path:gsub("\\", "/")
		self.file_map[normalized:lower()] = path_util.join(self.skin.path, relative_path)
	end
	if self.fallback_directory then
		local ok, file_names = pcall(love.filesystem.getDirectoryItems, self.fallback_directory)
		if ok then
			for _, file_name in ipairs(file_names) do
				local asset = self.fallback_directory .. "/" .. file_name
				self.fallback_file_map[file_name:lower()] = asset
			end
		end
	end
	if self.fallback_fs and self.fallback_archive then
		for _, file_name in ipairs(self.fallback_fs:getDirectoryItems("")) do
			self.fallback_file_map[file_name:lower()] = self.fallback_archive .. "/" .. file_name
		end
	end
end

---@param skin rizu.skin.OsuSkinDiscovery?
function OsuManiaSkinGraphics:setSkin(skin)
	if self.skin == skin and (self.loaded or next(self.file_map)) then return end
	if self.loaded or next(self.images) then self:unload() end
	self.generation = self.generation + 1
	self.skin = skin
	self.frame_cache = {}
	self.animation_cache = {}
	self:indexFiles()
end

function OsuManiaSkinGraphics:setFallbackDirectory(directory)
	if self.fallback_directory == directory then return end
	if self.loaded or next(self.images) then self:unload() end
	self.generation = self.generation + 1
	self.fallback_directory = directory
	self.frame_cache = {}
	self.animation_cache = {}
	self:indexFiles()
end

---@param archive_path string
function OsuManiaSkinGraphics:setFallbackArchive(archive_path)
	if self.fallback_archive == archive_path then return end
	if self.loaded or next(self.images) then self:unload() end
	local archive = archive_cache[archive_path]
	if not archive then
		local content = love.filesystem.read(archive_path)
		if content then
			archive = ZipFilesystem(content)
			archive_cache[archive_path] = archive
		end
	end
	self.fallback_archive = archive_path
	self.fallback_fs = archive
	self.generation = self.generation + 1
	self.frame_cache = {}
	self.animation_cache = {}
	self:indexFiles()
end

---@param name string
---@param file_map {[string]: string}?
---@return string?
function OsuManiaSkinGraphics:findAsset(name, file_map)
	if type(name) ~= "string" or name == "" then return nil end
	name = name:gsub("\\", "/"):gsub("^/+", ""):lower()
	local stem = name:gsub("%.png$", "")
	for _, map in ipairs(file_map and {file_map} or {self.file_map, self.fallback_file_map}) do
		for _, candidate in ipairs({stem .. "@2x.png", stem .. ".png"}) do
			local path = map[candidate]
			if path then return path end
		end
	end
end

---@param base string
---@param file_map {[string]: string}?
---@return {index: integer, path: string}[]
function OsuManiaSkinGraphics:findAnimationAssets(base, file_map)
	if not file_map then
		local assets = self:findAnimationAssets(base, self.file_map)
		if #assets > 0 or self:findAsset(base, self.file_map) then return assets end
		return self:findAnimationAssets(base, self.fallback_file_map)
	end
	if type(base) ~= "string" or base == "" then return {} end
	base = base:gsub("\\", "/"):gsub("^/+", ""):gsub("%.png$", ""):lower()
	---@type string?, string?
	local directory, stem = base:match("^(.*[/])([^/]+)$")
	directory = directory or ""
	stem = stem or base
	local escaped_stem = stem:gsub("([^%w])", "%%%1")
	---@type {[integer]: {index: integer, path: string, high_density: boolean}}
	local found = {}
	for normalized_path, path in pairs(file_map) do
		---@type string?, string?
		local file_directory, file_name = normalized_path:match("^(.*[/])([^/]+)$")
		file_directory = file_directory or ""
		file_name = file_name or normalized_path
		if file_directory == directory then
			local index = file_name:match("^" .. escaped_stem .. "%-([0-9]+)@2x%.png$")
				or file_name:match("^" .. escaped_stem .. "%-([0-9]+)%.png$")
			if index then
				local frame_index = assert(tonumber(index))
				local frame = found[frame_index]
				local high_density = file_name:find("@2x.png", 1, true) ~= nil
				if not frame or high_density then
					found[frame_index] = {index = frame_index, path = path, high_density = high_density}
				end
			end
		end
	end

	---@type integer[]
	local indices = {}
	for index in pairs(found) do indices[#indices + 1] = index end
	table.sort(indices)
	---@type {index: integer, path: string}[]
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
		local image = create_image(path)
		if image then
			self.images[path] = image
			self.image_density[image] = path:lower():match("@2x%.png$") and 2 or 1
			return image
		end
		self.images[path] = false
		return nil
	end
	local fs = self.fs
	local read_path = path
	if self.fallback_fs and self.fallback_archive
		and path:sub(1, #self.fallback_archive + 1) == self.fallback_archive .. "/" then
		fs = self.fallback_fs
		read_path = path:sub(#self.fallback_archive + 2)
	end
	if not fs then return nil end

	local ok_read, content = pcall(fs.read, fs, read_path)
	if not ok_read or not content then
		self.images[path] = false
		return nil
	end
	local ok_data, file_data = pcall(love.filesystem.newFileData, content, path)
	if not ok_data then
		self.images[path] = false
		return nil
	end
	local image = create_image(file_data)
	release_resource(file_data)
	if not image then
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
	---@type love.Image[]
	local frames = {}
	---@param name string?
	---@param file_map {[string]: string}
	local function load_name(name, file_map)
		if not name or name == "" then return end
		local path = self:findAsset(name, file_map)
		local image = path and self:loadImage(path) or nil
		if image then frames[1] = image end
	end
	for _, file_map in ipairs({self.file_map, self.fallback_file_map}) do
		load_name(image_name, file_map)
		if #frames == 0 and fallback_name ~= image_name then load_name(fallback_name, file_map) end
		if #frames > 0 then break end
	end
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
	---@param name string?
	---@param file_map {[string]: string}
	---@return love.Image[]
	local function load_animation(name, file_map)
		if name == nil then return {} end
		---@cast name string
		local discovered = self:findAnimationAssets(name, file_map)
		---@type love.Image[]
		local frames = {}
		for _, asset in ipairs(discovered) do
			local image = self:loadImage(asset.path)
			if image then frames[#frames + 1] = image end
		end
		if #frames == 0 then
			local path = self:findAsset(name, file_map)
			local image = path and self:loadImage(path) or nil
			if image then frames[1] = image end
		end
		return frames
	end
	local frames = {}
	for _, file_map in ipairs({self.file_map, self.fallback_file_map}) do
		frames = load_animation(image_name, file_map)
		if #frames == 0 and fallback_name ~= image_name then frames = load_animation(fallback_name, file_map) end
		if #frames > 0 then break end
	end
	self.animation_cache[key] = frames
	return frames
end

---@param image_name string
---@return love.Image[]
function OsuManiaSkinGraphics:getFallbackFrames(image_name)
	local key = "\0fallback\0" .. tostring(image_name or "")
	local cached = self.frame_cache[key]
	if cached then return cached end
	---@type love.Image[]
	local frames = {}
	local path = self:findAsset(image_name, self.fallback_file_map)
	local image = path and self:loadImage(path) or nil
	if image then frames[1] = image end
	self.frame_cache[key] = frames
	return frames
end

---@param assets {name: string?, fallback: string?, animation: boolean?}[]?
function OsuManiaSkinGraphics:load(assets)
	self.generation = self.generation + 1
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
	self.generation = self.generation + 1
	self:indexFiles()
end

return OsuManiaSkinGraphics
