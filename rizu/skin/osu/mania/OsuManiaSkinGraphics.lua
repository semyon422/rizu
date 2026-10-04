local class = require("class")
local path_util = require("path_util")
local ZipFilesystem = require("fs.ZipFilesystem")
local OsuManiaBatch = require("rizu.skin.osu.mania.OsuManiaBatch")
local ImageAtlasPacker = require("rizu.skin.ImageAtlasPacker")

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
---@param density number
---@return boolean, any
local function upload_image(source, density)
	local ok, image = pcall(love.graphics.newImage, source, {dpiscale = density})
	if ok then return true, image end
	return pcall(love.graphics.newImage, source)
end

---@param source any
---@param density number
---@return love.Image?
local function create_image(source, density)
	---@param image any
	---@return boolean
	local function is_valid(image)
		if not image then return false end
		local width, height = get_image_dimensions(image)
		if width and height and width > 0 and height > 0 then return true end
		release_resource(image)
		return false
	end

	-- Prefer LÖVE's direct loader. Besides being cheaper, it preserves the
	-- @2x DPI metadata carried by FileData and filesystem paths.
	local ok_image, image = upload_image(source, density)
	if ok_image and is_valid(image) then return image end

	-- osu! creates the GPU texture with each dimension capped at the maximum
	-- supported texture size, copying the bitmap from its top-left corner.
	-- Decode before uploading so a driver that rejects the original oversized
	-- image still produces the same texture as osu!.
	local ok_data, image_data = pcall(love.image.newImageData, source)
	if ok_data then
		local ok_limited, limited = pcall(limit_image_data, image_data)
		if ok_limited then
			local ok_limited_image, limited_image = upload_image(limited, density)
			release_resource(limited)
			if limited ~= image_data then release_resource(image_data) end
			if ok_limited_image and is_valid(limited_image) then return limited_image end
		else
			release_resource(image_data)
		end
	end

	return nil
end

---@param path string
---@return number
local function get_image_density(path)
	return path:lower():match("@2x%.png$") and 2 or 1
end

---@class rizu.skin.osu.mania.OsuManiaSkinGraphics.Frame
---@field texture love.Image
---@field quad love.Quad
---@field width number Logical width
---@field height number Logical height
---@field density number
---@field batch rizu.skin.osu.mania.OsuManiaBatch

---@alias rizu.skin.osu.mania.OsuManiaSkinGraphics.Image love.Image|rizu.skin.osu.mania.OsuManiaSkinGraphics.Frame

---@class rizu.skin.osu.mania.OsuManiaSkinGraphics.Asset
---@field name string?
---@field fallback string?
---@field animation boolean?
---@field group string?

---@class rizu.skin.osu.mania.OsuManiaSkinGraphics.Source
---@field image_data love.ImageData
---@field density number

---@class rizu.skin.osu.mania.OsuManiaSkinGraphics.PreparedGroup
---@field atlases love.ImageData[]
---@field locations {[string]: rizu.skin.ImageAtlasPacker.Location}
---@field densities {[string]: number}

---@class rizu.skin.osu.mania.OsuManiaSkinGraphics.Prepared
---@field groups {[string]: rizu.skin.osu.mania.OsuManiaSkinGraphics.PreparedGroup}
---@field standalone {[string]: rizu.skin.osu.mania.OsuManiaSkinGraphics.Source}

---@class rizu.skin.osu.mania.OsuManiaSkinGraphics
---@operator call: rizu.skin.osu.mania.OsuManiaSkinGraphics
---@field fs fs.IFilesystem?
---@field skin rizu.skin.OsuSkinDiscovery?
---@field images {[string]: love.Image|false}
---@field file_map {[string]: string} Lowercase selected skin asset path to full filesystem path.
---@field fallback_file_map {[string]: string}
---@field fallback_archive string?
---@field fallback_fs fs.ZipFilesystem?
---@field frame_cache {[string]: rizu.skin.osu.mania.OsuManiaSkinGraphics.Image[]}
---@field animation_cache {[string]: rizu.skin.osu.mania.OsuManiaSkinGraphics.Image[]}
---@field image_density {[love.Image]: number}
---@field loaded boolean
---@field generation integer
---@field fallback_directory string?
---@field atlas_images {[string]: love.Image[]}
---@field atlas_frames {[string]: {[string]: rizu.skin.osu.mania.OsuManiaSkinGraphics.Frame}}
---@field atlas_limit integer
---@field texture_limit integer?
---@field prepared rizu.skin.osu.mania.OsuManiaSkinGraphics.Prepared?
---@field atlas_mode boolean
---@field defer_grouped boolean
---@field hide_unbatched boolean
---@field grouped_paths {[string]: {[string]: boolean}}
---@field batch rizu.skin.osu.mania.OsuManiaBatch
---@field repeated_quad love.Quad?
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
	self.atlas_images = {}
	self.atlas_frames = {}
	self.prepared = nil
	self.atlas_limit = ImageAtlasPacker.max_atlas_width
	self.texture_limit = nil
	self.atlas_mode = false
	self.defer_grouped = false
	self.hide_unbatched = false
	self.grouped_paths = {}
	self.batch = OsuManiaBatch()
	self:setSkin(skin)
end

---@param limit integer
function OsuManiaSkinGraphics:setAtlasLimit(limit)
	assert(type(limit) == "number" and limit > 0 and limit % 1 == 0)
	self.atlas_limit = limit
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
	if self.loaded or next(self.images) or self.prepared then self:unload() end
	self.generation = self.generation + 1
	self.skin = skin
	self.frame_cache = {}
	self.animation_cache = {}
	self:indexFiles()
end

function OsuManiaSkinGraphics:setFallbackDirectory(directory)
	if self.fallback_directory == directory then return end
	if self.loaded or next(self.images) or self.prepared then self:unload() end
	self.generation = self.generation + 1
	self.fallback_directory = directory
	self.frame_cache = {}
	self.animation_cache = {}
	self:indexFiles()
end

---@param archive_path string
function OsuManiaSkinGraphics:setFallbackArchive(archive_path)
	if self.fallback_archive == archive_path then return end
	if self.loaded or next(self.images) or self.prepared then self:unload() end
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
		local density = get_image_density(path)
		local image = create_image(path, density)
		if image then
			self.images[path] = image
			self.image_density[image] = density
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
	local density = get_image_density(path)
	local image = create_image(file_data, density)
	release_resource(file_data)
	if not image then
		self.images[path] = false
		return nil
	end
	self.images[path] = image
	self.image_density[image] = density
	return image
end

---@param image rizu.skin.osu.mania.OsuManiaSkinGraphics.Image
---@return number
function OsuManiaSkinGraphics:getImageDensity(image)
	if image.texture then return image.density end
	return self.image_density[image] or 1
end

---@param image_name string?
---@param fallback_name string?
---@param group string?
---@return rizu.skin.osu.mania.OsuManiaSkinGraphics.Image[]
function OsuManiaSkinGraphics:getFrames(image_name, fallback_name, group)
	local key = tostring(group or "") .. "\0" .. tostring(image_name or "") .. "\0" .. tostring(fallback_name or "")
	local cached = self.frame_cache[key]
	if cached then return cached end
	---@type rizu.skin.osu.mania.OsuManiaSkinGraphics.Image[]
	local frames = {}
	---@param name string?
	---@param file_map {[string]: string}
	local function load_name(name, file_map)
		if not name or name == "" then return end
		local path = self:findAsset(name, file_map)
		local image = path and self:getFrame(path, group) or nil
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
---@param group string?
---@return rizu.skin.osu.mania.OsuManiaSkinGraphics.Image[]
function OsuManiaSkinGraphics:getAnimationFrames(image_name, fallback_name, group)
	local key = tostring(group or "") .. "\0" .. tostring(image_name or "") .. "\0" .. tostring(fallback_name or "")
	local cached = self.animation_cache[key]
	if cached then return cached end
	---@param name string?
	---@param file_map {[string]: string}
	---@return rizu.skin.osu.mania.OsuManiaSkinGraphics.Image[]
	local function load_animation(name, file_map)
		if name == nil then return {} end
		---@cast name string
		local discovered = self:findAnimationAssets(name, file_map)
		---@type rizu.skin.osu.mania.OsuManiaSkinGraphics.Image[]
		local frames = {}
		for _, asset in ipairs(discovered) do
			local image = self:getFrame(asset.path, group)
			if image then frames[#frames + 1] = image end
		end
		if #frames == 0 then
			local path = self:findAsset(name, file_map)
			local image = path and self:getFrame(path, group) or nil
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
---@return rizu.skin.osu.mania.OsuManiaSkinGraphics.Image[]
function OsuManiaSkinGraphics:getFallbackFrames(image_name)
	local key = "\0fallback\0" .. tostring(image_name or "")
	local cached = self.frame_cache[key]
	if cached then return cached end
	---@type rizu.skin.osu.mania.OsuManiaSkinGraphics.Image[]
	local frames = {}
	local path = self:findAsset(image_name, self.fallback_file_map)
	local image = path and self:getFrame(path, nil) or nil
	if image then frames[1] = image end
	self.frame_cache[key] = frames
	return frames
end

---@param limit integer
function OsuManiaSkinGraphics:setTextureLimit(limit)
	assert(type(limit) == "number" and limit > 0 and limit % 1 == 0)
	self.texture_limit = limit
end


---@param path string
---@return love.ImageData?
function OsuManiaSkinGraphics:loadImageData(path)
	local fs, read_path = self.fs, path
	local directory = self.fallback_directory
	local is_directory = directory and path:sub(1, #directory + 1) == directory .. "/"
	if self.fallback_fs and self.fallback_archive and path:sub(1, #self.fallback_archive + 1) == self.fallback_archive .. "/" then
		fs, read_path = self.fallback_fs, path:sub(#self.fallback_archive + 2)
	end
	if is_directory then
		local ok, data = pcall(love.image.newImageData, path)
		return ok and data or nil
	end
	if not fs then return nil end
	local ok_read, content = pcall(fs.read, fs, read_path)
	if not ok_read or not content then return nil end
	local ok_file, file_data = pcall(love.filesystem.newFileData, content, path)
	if not ok_file then return nil end
	local ok_data, data = pcall(love.image.newImageData, file_data)
	release_resource(file_data)
	return ok_data and data or nil
end

---@param image_data love.ImageData
---@param limit integer?
---@return love.ImageData
local function crop_image_data(image_data, limit)
	if not limit then return image_data end
	local width, height = image_data:getDimensions()
	if width <= limit and height <= limit then return image_data end
	local cropped = love.image.newImageData(math.min(width, limit), math.min(height, limit))
	cropped:paste(image_data, 0, 0, 0, 0, cropped:getWidth(), cropped:getHeight())
	release_resource(image_data)
	return cropped
end

---@param prepared rizu.skin.osu.mania.OsuManiaSkinGraphics.Prepared
local function release_prepared(prepared)
	for _, group in pairs(prepared.groups) do
		for _, data in ipairs(group.atlases) do release_resource(data) end
	end
	for _, source in pairs(prepared.standalone) do release_resource(source.image_data) end
end

---Decode, crop and pack on the CPU. Device limits are supplied by the caller.
---@param assets rizu.skin.osu.mania.OsuManiaSkinGraphics.Asset[]?
---@return rizu.skin.osu.mania.OsuManiaSkinGraphics.Prepared
function OsuManiaSkinGraphics:prepare(assets)
	assert(not self.loaded and not next(self.images) and not next(self.atlas_images),
		"unload GPU resources before preparing skin graphics")
	if self.prepared then release_prepared(self.prepared) end
	self.prepared = nil
	self.grouped_paths, self.frame_cache, self.animation_cache = {}, {}, {}
	self.atlas_mode = true
	local prepared = {groups = {}, standalone = {}} ---@type rizu.skin.osu.mania.OsuManiaSkinGraphics.Prepared
	local sources = {} ---@type {[string]: rizu.skin.osu.mania.OsuManiaSkinGraphics.Source|false}
	local groups = {} ---@type {[string]: {[string]: rizu.skin.osu.mania.OsuManiaSkinGraphics.Source}}
	---@param path string
	---@return rizu.skin.osu.mania.OsuManiaSkinGraphics.Source?
	local function decode(path)
		local cached = sources[path]
		if cached ~= nil then return cached or nil end
		local data = self:loadImageData(path)
		if not data then sources[path] = false; return end
		local source = {image_data = data, density = get_image_density(path)}
		sources[path] = source
		source.image_data = crop_image_data(data, self.texture_limit)
		return source
	end
	---@param name string?
	---@param map {[string]: string}
	---@param animation boolean?
	---@return string[]
	local function paths_for(name, map, animation)
		if not name or name == "" then return {} end
		if animation then
			local paths = {} ---@type string[]
			for _, asset in ipairs(self:findAnimationAssets(name, map)) do paths[#paths + 1] = asset.path end
			if #paths > 0 then return paths end
		end
		local path = self:findAsset(name, map)
		return path and {path} or {}
	end
	---@param asset rizu.skin.osu.mania.OsuManiaSkinGraphics.Asset
	local function add_asset(asset)
		local group_name = asset.group or "standalone"
		local group = groups[group_name] or {}
		groups[group_name] = group
		local names = {} ---@type string[]
		if asset.name then names[#names + 1] = asset.name end
		if asset.fallback and asset.fallback ~= asset.name then names[#names + 1] = asset.fallback end
		for _, map in ipairs({self.file_map, self.fallback_file_map}) do
			for _, name in ipairs(names) do
				local found = false
				for _, path in ipairs(paths_for(name, map, asset.animation)) do
					local source = decode(path)
					if source then group[path] = source; found = true end
				end
				if found then return end
			end
		end
	end
	local ok, err = xpcall(function()
		for _, asset in ipairs(assets or {}) do add_asset(asset) end
		local pixel = love.image.newImageData(1, 1)
		local source = {image_data = pixel, density = 1}
		sources["\0white"] = source
		pixel:setPixel(0, 0, 1, 1, 1, 1)
		groups.playfield = groups.playfield or {}
		groups.playfield["\0white"] = source
		local packer = ImageAtlasPacker()
		local limit = math.min(self.atlas_limit, self.texture_limit or self.atlas_limit)
		packer.max_atlas_width, packer.max_atlas_height = limit, limit
		for name, entries in pairs(groups) do
			local input = {} ---@type {[string]: love.ImageData}
			local densities = {} ---@type {[string]: number}
			self.grouped_paths[name] = {}
			local oversized = {} ---@type string[]
			for path, entry in pairs(entries) do
				self.grouped_paths[name][path] = true
				local width, height = entry.image_data:getDimensions()
				if name == "standalone" then
					prepared.standalone[path] = entry
				elseif width + 2 <= limit and height + 2 <= limit then
					input[path] = entry.image_data
					densities[path] = entry.density
				else
					oversized[#oversized + 1] = path
				end
			end
			if name ~= "standalone" then
				local atlases, locations = packer:pack(input)
				prepared.groups[name] = {atlases = atlases, locations = locations, densities = densities}
				if #oversized > 0 then
					-- Pack existing, already-bordered pages alongside cropped bodies.
					-- This avoids one texture switch per hold body/tail pair while
					-- preserving the exact crop and normal sprite extrusion.
					local page_data = {} ---@type {[string]: love.ImageData}
					local page_names = {} ---@type string[]
					for layer, data in ipairs(atlases) do
						local key = "\0page" .. layer
						page_names[layer] = key
						page_data[key] = data
					end
					for _, path in ipairs(oversized) do page_data[path] = entries[path].image_data end
					local large_packer = ImageAtlasPacker()
					large_packer.border = 0
					local device_limit = self.texture_limit or ImageAtlasPacker.max_atlas_width
					large_packer.max_atlas_width, large_packer.max_atlas_height = device_limit, device_limit
					local pages, placements = large_packer:pack(page_data)
					prepared.groups[name].atlases = pages
					for _, location in pairs(locations) do
						local page = placements[page_names[location.layer]]
						location.x, location.y = location.x + page.x, location.y + page.y
						location.layer = page.layer
					end
					for _, path in ipairs(oversized) do
						locations[path] = placements[path]
						densities[path] = entries[path].density
					end
					for _, data in ipairs(atlases) do release_resource(data) end
				end
			end
		end
	end, debug.traceback)
	for path, source in pairs(sources) do
		if source and (not ok or not prepared.standalone[path]) then release_resource(source.image_data) end
	end
	if not ok then
		prepared.standalone = {}
		release_prepared(prepared)
		self.grouped_paths, self.atlas_mode = {}, false
		error(err, 0)
	end
	self.prepared = prepared
	return prepared
end

---Upload only: no decoding, cropping, packing, filesystem or ImageData creation.
function OsuManiaSkinGraphics:upload()
	local prepared = assert(self.prepared, "no prepared skin graphics")
	local ok, err = xpcall(function()
		for name, group in pairs(prepared.groups) do
			local images = {} ---@type love.Image[]
			local frames = {} ---@type {[string]: rizu.skin.osu.mania.OsuManiaSkinGraphics.Frame}
			self.atlas_images[name], self.atlas_frames[name] = images, frames
			for layer, data in ipairs(group.atlases) do
				local image = love.graphics.newImage(data, {dpiscale = 1})
				images[layer] = image
				image:setWrap("clamp", "clamp")
				self.batch:loadPage(image)
			end
			for path, location in pairs(group.locations) do
				local image = images[location.layer]
				local density = group.densities[path]
				local quad = love.graphics.newQuad(location.x, location.y, location.width, location.height,
					image:getWidth(), image:getHeight())
				frames[path] = {texture = image, quad = quad, width = location.width / density,
					height = location.height / density, density = density, batch = self.batch}
			end
		end
		for path, source in pairs(prepared.standalone) do
			local image = love.graphics.newImage(source.image_data, {dpiscale = source.density})
			self.images[path] = image
			self.image_density[image] = source.density
		end
		self.repeated_quad = love.graphics.newQuad(0, 0, 1, 1, 1, 1)
	end, debug.traceback)
	if not ok then self:unload(); error(err, 0) end
	release_prepared(prepared)
	self.prepared = nil
	self.loaded = true
	self.frame_cache, self.animation_cache = {}, {}
	self.generation = self.generation + 1
end

---@param path string
---@param group string?
---@return rizu.skin.osu.mania.OsuManiaSkinGraphics.Image?
function OsuManiaSkinGraphics:getFrame(path, group)
	local frame = group and self.atlas_frames[group] and self.atlas_frames[group][path]
	if frame then return frame end
	if self.hide_unbatched then return end
	if self.atlas_mode then
		if group and not (self.grouped_paths[group] and self.grouped_paths[group][path]) then return end
		return self.images[path] or nil
	end
	if group and self.defer_grouped then return end
	return self:loadImage(path)
end

---@param group string
---@param path string
---@return rizu.skin.osu.mania.OsuManiaSkinGraphics.Frame?
function OsuManiaSkinGraphics:getAtlasFrame(group, path)
	return self.atlas_frames[group] and self.atlas_frames[group][path]
end

---@param frame rizu.skin.osu.mania.OsuManiaSkinGraphics.Image
---@return number, number
function OsuManiaSkinGraphics:getFrameDimensions(frame)
	if frame.texture then return frame.width, frame.height end
	if frame.getDimensions then return frame:getDimensions() end
	return frame:getWidth(), frame:getHeight()
end

---@param assets {name: string?, fallback: string?, animation: boolean?, group: string?}[]?
function OsuManiaSkinGraphics:load(assets)
	local legacy = true
	for _, asset in ipairs(assets or {}) do if asset.group then legacy = false; break end end
	if legacy then
		self.generation = self.generation + 1; self.loaded = true
		for _, asset in ipairs(assets or {}) do
			if asset.animation then self:getAnimationFrames(asset.name, asset.fallback)
			else self:getFrames(asset.name, asset.fallback) end
		end
		return
	end
	self:unload()
	self:prepare(assets)
	self:upload()
end

function OsuManiaSkinGraphics:unload()
	self.batch:unload()
	if self.repeated_quad then release_resource(self.repeated_quad) end
	self.repeated_quad = nil
	if self.prepared then release_prepared(self.prepared) end
	for _, image in pairs(self.images) do if image then release_resource(image) end end
	for _, images in pairs(self.atlas_images) do
		for _, image in ipairs(images) do release_resource(image) end
	end
	for _, frames in pairs(self.atlas_frames) do
		for _, frame in pairs(frames) do release_resource(frame.quad) end
	end
	self.images, self.atlas_images, self.atlas_frames = {}, {}, {}
	self.prepared = nil
	self.grouped_paths, self.frame_cache, self.animation_cache, self.image_density = {}, {}, {}, {}
	self.loaded, self.atlas_mode = false, false
	self.generation = self.generation + 1
end

return OsuManiaSkinGraphics
