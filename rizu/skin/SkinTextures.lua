local class = require("class")
local path_util = require("path_util")
local thread = require("thread")
local LoveFilesystem = require("fs.LoveFilesystem")
local SpriteBatch = require("rizu.skin.SpriteBatch")
local SkinAtlas = require("rizu.skin.SkinAtlas")
local ImageAtlasPacker = require("rizu.skin.ImageAtlasPacker")

local release_resource = SkinAtlas.release
local get_image_density = SkinAtlas.getDensity

---Runs in a worker thread: it owns no GPU state, so everything it touches is plain data or ImageData.
---Errors are returned, not thrown: the thread pool would raise them in the main loop.
local prepare_in_thread = thread.async(function(request)
	require("love.filesystem")
	require("love.image")
	local SkinAtlas = require("rizu.skin.SkinAtlas")
	local LoveFilesystem = require("fs.LoveFilesystem")
	local loader = SkinAtlas.newImageDataLoader(LoveFilesystem(), request.fallback_archive)
	return xpcall(SkinAtlas.prepare, debug.traceback, request, loader)
end)

---Decodes and shrinks a texture in a worker thread. Errors are returned as nil, not thrown.
local thumbnail_in_thread = thread.future(function(path, fallback_archive, size)
	require("love.filesystem")
	require("love.image")
	local SkinAtlas = require("rizu.skin.SkinAtlas")
	local LoveFilesystem = require("fs.LoveFilesystem")
	local loader = SkinAtlas.newImageDataLoader(LoveFilesystem(), fallback_archive)
	local ok, data = pcall(SkinAtlas.loadThumbnail, loader, path, size)
	return ok and data or nil
end)

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

---@class rizu.skin.SkinTextures.Frame
---@field texture love.Image
---@field quad love.Quad
---@field width number Logical width
---@field height number Logical height
---@field density number
---@field batch rizu.skin.SpriteBatch

---@alias rizu.skin.SkinTextures.Image love.Image|rizu.skin.SkinTextures.Frame

---@alias rizu.skin.SkinTextures.Asset rizu.skin.SkinAtlas.Asset
---@alias rizu.skin.SkinTextures.Prepared rizu.skin.SkinAtlas.Prepared

---Where textures come from: a skin directory, with its file list when the caller already has one.
---@class rizu.skin.SkinTextures.Source
---@field path string
---@field files string[]? Paths relative to `path`. The directory is listed when omitted.

---Textures of one skin of any format: name lookup that ignores case and prefers @2x, animation
---frames, atlases packed in a worker thread and a sprite batch. An optional fallback archive
---supplies what the skin lacks.
---@class rizu.skin.SkinTextures
---@operator call: rizu.skin.SkinTextures
---@field fs fs.IFilesystem?
---@field skin rizu.skin.SkinTextures.Source?
---@field images {[string]: love.Image|false}
---@field file_map {[string]: string} Lowercase selected skin asset path to full filesystem path.
---@field fallback_file_map {[string]: string}
---@field fallback_archive string?
---@field fallback_fs fs.ZipFilesystem?
---@field frame_cache {[string]: rizu.skin.SkinTextures.Image[]}
---@field animation_cache {[string]: rizu.skin.SkinTextures.Image[]}
---@field image_density {[love.Image]: number}
---@field loaded boolean
---@field atlas_images {[string]: love.Image[]}
---@field atlas_frames {[string]: {[string]: rizu.skin.SkinTextures.Frame}}
---@field atlas_limit integer
---@field texture_limit integer?
---@field prepared rizu.skin.SkinTextures.Prepared?
---@field atlas_mode boolean
---@field grouped_paths {[string]: {[string]: boolean}}
---@field load_token integer Changes on unload(), so a load that was waiting for the worker knows it was cancelled.
---@field loading boolean
---@field batch rizu.skin.SpriteBatch
---@field repeated_quad love.Quad?
local SkinTextures = class()

---Replaceable so tests can stand in for the worker.
---@type fun(request: rizu.skin.SkinAtlas.Request): boolean, rizu.skin.SkinAtlas.Prepared|string
SkinTextures.prepareInThread = prepare_in_thread

---@param fs fs.IFilesystem?
---@param skin rizu.skin.SkinTextures.Source?
function SkinTextures:new(fs, skin)
	self.fs = fs
	self.skin = nil
	self.images = {}
	self.file_map = {}
	self.fallback_file_map = {}
	self.frame_cache = {}
	self.animation_cache = {}
	self.image_density = {}
	self.loaded = false
	self.atlas_images = {}
	self.atlas_frames = {}
	self.prepared = nil
	self.atlas_limit = ImageAtlasPacker.max_atlas_width
	self.texture_limit = nil
	self.atlas_mode = false
	self.grouped_paths = {}
	self.load_token = 0
	self.loading = false
	self.batch = SpriteBatch()
	self:setSkin(skin)
end

---@param limit integer
function SkinTextures:setAtlasLimit(limit)
	assert(type(limit) == "number" and limit > 0 and limit % 1 == 0)
	self.atlas_limit = limit
end

---@param fs fs.IFilesystem
---@param directory string
---@param relative string?
---@param files string[]
---@return string[]
local function list_files(fs, directory, relative, files)
	for _, name in ipairs(fs:getDirectoryItems(directory)) do
		local path = path_util.join(directory, name)
		local relative_path = relative and path_util.join(relative, name) or name
		local info = fs:getInfo(path)
		if info and info.type == "directory" then
			list_files(fs, path, relative_path, files)
		elseif info then
			files[#files + 1] = relative_path
		end
	end
	return files
end

function SkinTextures:indexFiles()
	self.file_map = {}
	self.fallback_file_map = {}
	local skin = self.skin
	local files = skin and skin.files
	if skin and not files and self.fs and self.fs:getInfo(skin.path) then
		files = list_files(self.fs, skin.path, nil, {})
	end
	for _, relative_path in ipairs(files or {}) do
		local normalized = relative_path:gsub("\\", "/")
		self.file_map[normalized:lower()] = path_util.join(self.skin.path, relative_path)
	end
	if self.fallback_fs and self.fallback_archive then
		for _, file_name in ipairs(self.fallback_fs:getDirectoryItems("")) do
			self.fallback_file_map[file_name:lower()] = self.fallback_archive .. "/" .. file_name
		end
	end
end

---@param skin rizu.skin.SkinTextures.Source?
function SkinTextures:setSkin(skin)
	if self.skin == skin and (self.loaded or next(self.file_map)) then return end
	if self.loaded or next(self.images) or self.prepared then self:unload() end
	self.skin = skin
	self.frame_cache = {}
	self.animation_cache = {}
	self:indexFiles()
end

---@param archive_path string
function SkinTextures:setFallbackArchive(archive_path)
	if self.fallback_archive == archive_path then return end
	if self.loaded or next(self.images) or self.prepared then self:unload() end
	self.fallback_archive = archive_path
	self.fallback_fs = SkinAtlas.getArchive(archive_path)
	self.frame_cache = {}
	self.animation_cache = {}
	self:indexFiles()
end

---@param name string
---@param file_map {[string]: string}?
---@return string?
function SkinTextures:findAsset(name, file_map)
	return SkinAtlas.findAsset(name, file_map and {file_map} or {self.file_map, self.fallback_file_map})
end

---Lowercase image names without density, extension and animation frame number, for pickers.
---@return string[]
function SkinTextures:getTextureNames()
	local set = {} ---@type {[string]: true}
	for _, map in ipairs({self.file_map, self.fallback_file_map}) do
		for path in pairs(map) do
			local stem = path:match("^(.-)@2x%.png$") or path:match("^(.-)%.png$")
			if stem then set[stem:match("^(.*)%-%d+$") or stem] = true end
		end
	end
	local names = {} ---@type string[]
	for name in pairs(set) do names[#names + 1] = name end
	table.sort(names)
	return names
end

---Prefixes that have at least the 0 and 1 glyphs of a bitmap font.
---@return string[]
function SkinTextures:getBitmapFontPrefixes()
	local prefixes = {} ---@type string[]
	local seen = {} ---@type {[string]: true}
	for _, map in ipairs({self.file_map, self.fallback_file_map}) do
		for path in pairs(map) do
			local prefix = path:match("^(.-)%-0@2x%.png$") or path:match("^(.-)%-0%.png$")
			if prefix and not seen[prefix] and self:findAsset(prefix .. "-1") then
				seen[prefix] = true
				prefixes[#prefixes + 1] = prefix
			end
		end
	end
	table.sort(prefixes)
	return prefixes
end

---@param base string
---@param file_map {[string]: string}?
---@return {index: integer, path: string}[]
function SkinTextures:findAnimationAssets(base, file_map)
	if not file_map then
		local assets = SkinAtlas.findAnimationAssets(base, self.file_map)
		if #assets > 0 or self:findAsset(base, self.file_map) then return assets end
		return SkinAtlas.findAnimationAssets(base, self.fallback_file_map)
	end
	return SkinAtlas.findAnimationAssets(base, file_map)
end

---@param path string
---@return love.Image?
function SkinTextures:loadImage(path)
	local cached = self.images[path]
	if cached ~= nil then return cached or nil end
	local image, density = self:readImage(path)
	self.images[path] = image or false
	if image then self.image_density[image] = density end
	return image
end

---Decodes a file of the skin or of the fallback archive into a new image the caller owns.
---@param path string Full path, as the file maps hold it.
---@return love.Image?
---@return number density
function SkinTextures:readImage(path)
	local density = get_image_density(path)
	local fs = self.fs
	local read_path = path
	if self.fallback_fs and self.fallback_archive
		and path:sub(1, #self.fallback_archive + 1) == self.fallback_archive .. "/" then
		fs = self.fallback_fs
		read_path = path:sub(#self.fallback_archive + 2)
	end
	if not fs then return nil, density end

	local ok_read, content = pcall(fs.read, fs, read_path)
	if not ok_read or not content then return nil, density end
	local ok_data, file_data = pcall(love.filesystem.newFileData, content, path)
	if not ok_data then return nil, density end
	local image = create_image(file_data, density)
	release_resource(file_data)
	return image, density
end

---A thumbnail being decoded: once `done`, `result[1]` is a small ImageData the caller releases, or nil.
---@alias rizu.skin.SkinTextures.Thumbnail thread.Future

---A small copy of a texture for a picker, outside the caches and atlases. It is decoded in a worker
---thread when the files are reachable from one, so huge textures do not freeze the game.
---@param name string Texture name, as getTextureNames() lists them.
---@param size integer The thumbnail fits a square of this size.
---@return rizu.skin.SkinTextures.Thumbnail
function SkinTextures:loadThumbnail(name, size)
	local path = self:findAsset(name)
	if not path then
		-- getTextureNames() lists an animation by its name without the frame number.
		local frame = self:findAnimationAssets(name)[1]
		path = frame and frame.path
	end
	if not path then return {done = true, result = {n = 0}} end
	if self.fs and LoveFilesystem * self.fs then return thumbnail_in_thread(path, self.fallback_archive, size) end
	local loader = SkinAtlas.newImageDataLoader(self.fs, self.fallback_archive)
	local ok, data = pcall(SkinAtlas.loadThumbnail, loader, path, size)
	return {done = true, result = {n = 1, ok and data or nil}}
end

---@param image rizu.skin.SkinTextures.Image
---@return number
function SkinTextures:getImageDensity(image)
	if image.texture then return image.density end
	return self.image_density[image] or 1
end

---@param image_name string?
---@param fallback_name string?
---@param group string?
---@param skin_only boolean? ignore the bundled fallback skin
---@return rizu.skin.SkinTextures.Image[]
function SkinTextures:getFrames(image_name, fallback_name, group, skin_only)
	local key = tostring(group or "") .. "\0" .. tostring(image_name or "") .. "\0" .. tostring(fallback_name or "") .. (skin_only and "\0skin" or "")
	local cached = self.frame_cache[key]
	if cached then return cached end
	---@type rizu.skin.SkinTextures.Image[]
	local frames = {}
	---@param name string?
	---@param file_map {[string]: string}
	local function load_name(name, file_map)
		if not name or name == "" then return end
		local path = self:findAsset(name, file_map)
		local image = path and self:getFrame(path, group) or nil
		if image then frames[1] = image end
	end
	for _, file_map in ipairs(skin_only and {self.file_map} or {self.file_map, self.fallback_file_map}) do
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
---@param skin_only boolean? ignore the bundled fallback skin
---@return rizu.skin.SkinTextures.Image[]
function SkinTextures:getAnimationFrames(image_name, fallback_name, group, skin_only)
	local key = tostring(group or "") .. "\0" .. tostring(image_name or "") .. "\0" .. tostring(fallback_name or "") .. (skin_only and "\0skin" or "")
	local cached = self.animation_cache[key]
	if cached then return cached end
	---@param name string?
	---@param file_map {[string]: string}
	---@return rizu.skin.SkinTextures.Image[]
	local function load_animation(name, file_map)
		if name == nil then return {} end
		---@cast name string
		local discovered = self:findAnimationAssets(name, file_map)
		---@type rizu.skin.SkinTextures.Image[]
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
	for _, file_map in ipairs(skin_only and {self.file_map} or {self.file_map, self.fallback_file_map}) do
		frames = load_animation(image_name, file_map)
		if #frames == 0 and fallback_name ~= image_name then frames = load_animation(fallback_name, file_map) end
		if #frames > 0 then break end
	end
	self.animation_cache[key] = frames
	return frames
end

---@param image_name string
---@return rizu.skin.SkinTextures.Image[]
function SkinTextures:getFallbackFrames(image_name)
	local key = "\0fallback\0" .. tostring(image_name or "")
	local cached = self.frame_cache[key]
	if cached then return cached end
	---@type rizu.skin.SkinTextures.Image[]
	local frames = {}
	local path = self:findAsset(image_name, self.fallback_file_map)
	local image = path and self:getFrame(path, nil) or nil
	if image then frames[1] = image end
	self.frame_cache[key] = frames
	return frames
end

---@param limit integer
function SkinTextures:setTextureLimit(limit)
	assert(type(limit) == "number" and limit > 0 and limit % 1 == 0)
	self.texture_limit = limit
end


---@param path string
---@return love.ImageData?
function SkinTextures:loadImageData(path)
	if not self.fs then return nil end
	return SkinAtlas.newImageDataLoader(self.fs, self.fallback_archive)(path)
end

---@param assets rizu.skin.SkinTextures.Asset[]?
---@return rizu.skin.SkinAtlas.Request
function SkinTextures:newRequest(assets)
	return {
		file_map = self.file_map,
		fallback_file_map = self.fallback_file_map,
		fallback_archive = self.fallback_archive,
		assets = assets or {},
		texture_limit = self.texture_limit,
		atlas_limit = self.atlas_limit,
	}
end

---@param prepared rizu.skin.SkinAtlas.Prepared
function SkinTextures:setPrepared(prepared)
	self.prepared = prepared
	self.grouped_paths = prepared.grouped_paths
	self.atlas_mode = true
end

function SkinTextures:assertUnloaded()
	assert(not self.loaded and not next(self.images) and not next(self.atlas_images),
		"unload GPU resources before preparing skin graphics")
	if self.prepared then SkinAtlas.releasePrepared(self.prepared) end
	self.prepared = nil
	self.grouped_paths, self.frame_cache, self.animation_cache = {}, {}, {}
end

---Decode, crop and pack on the CPU, on the calling thread.
---@param assets rizu.skin.SkinTextures.Asset[]?
---@return rizu.skin.SkinTextures.Prepared
function SkinTextures:prepare(assets)
	self:assertUnloaded()
	local prepared = SkinAtlas.prepare(self:newRequest(assets), function(path) return self:loadImageData(path) end)
	self:setPrepared(prepared)
	return prepared
end

---Upload only: no decoding, cropping, packing, filesystem or ImageData creation.
function SkinTextures:upload()
	local prepared = assert(self.prepared, "no prepared skin graphics")
	local ok, err = xpcall(function()
		for name, group in pairs(prepared.groups) do
			local images = {} ---@type love.Image[]
			local frames = {} ---@type {[string]: rizu.skin.SkinTextures.Frame}
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
	SkinAtlas.releasePrepared(prepared)
	self.prepared = nil
	self.loaded = true
	self.frame_cache, self.animation_cache = {}, {}
end

---@param path string
---@param group string?
---@return rizu.skin.SkinTextures.Image?
function SkinTextures:getFrame(path, group)
	local frame = group and self.atlas_frames[group] and self.atlas_frames[group][path]
	if frame then return frame end
	if self.atlas_mode then
		if group and not (self.grouped_paths[group] and self.grouped_paths[group][path]) then return end
		return self.images[path] or nil
	end
	-- Grouped resources are acquired only after upload, not during HUD construction.
	if group and not self.loaded then return end
	return self:loadImage(path)
end

---@param group string
---@param path string
---@return rizu.skin.SkinTextures.Frame?
function SkinTextures:getAtlasFrame(group, path)
	return self.atlas_frames[group] and self.atlas_frames[group][path]
end

---@param frame rizu.skin.SkinTextures.Image
---@return number, number
function SkinTextures:getFrameDimensions(frame)
	if frame.texture then return frame.width, frame.height end
	if frame.getDimensions then return frame:getDimensions() end
	return frame:getWidth(), frame:getHeight()
end

---@param assets rizu.skin.SkinTextures.Asset[]?
---@return boolean grouped True when the assets are grouped, so they are packed into atlases.
local function is_grouped(assets)
	for _, asset in ipairs(assets or {}) do if asset.group then return true end end
	return false
end

---@param assets rizu.skin.SkinTextures.Asset[]?
function SkinTextures:load(assets)
	if not is_grouped(assets) then
		self.loaded = true
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

---Like load(), but decodes and packs in a worker thread, so the calling coroutine yields instead of
---freezing the frame. Falls back to load() outside a coroutine or when the files are not reachable
---from a worker. Returns false when unload() cancelled the load or another load is already running.
---@param assets rizu.skin.SkinTextures.Asset[]?
---@return boolean loaded
function SkinTextures:loadAsync(assets)
	if self.loading then return false end
	if not is_grouped(assets) or not coroutine.running() or not (self.fs and LoveFilesystem * self.fs) then
		self:load(assets)
		return true
	end
	self:unload()
	self.loading = true
	local token = self.load_token
	---@type boolean, any
	local ok, prepared = self.prepareInThread(self:newRequest(assets))
	if token ~= self.load_token then
		if ok then SkinAtlas.releasePrepared(prepared) end
		return false
	end
	self.loading = false
	assert(ok, prepared)
	self:setPrepared(prepared)
	self:upload()
	return true
end

function SkinTextures:unload()
	self.batch:unload()
	if self.repeated_quad then release_resource(self.repeated_quad) end
	self.repeated_quad = nil
	if self.prepared then SkinAtlas.releasePrepared(self.prepared) end
	self.load_token = self.load_token + 1
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
	self.loaded, self.atlas_mode, self.loading = false, false, false
end

return SkinTextures
