local ZipFilesystem = require("fs.ZipFilesystem")
local ImageAtlasPacker = require("rizu.skin.ImageAtlasPacker")

---CPU half of osu! skin loading: finds files, decodes, crops and packs them into atlas pages.
---Pure functions over plain data and ImageData, with no GPU access, so a worker thread can run them.
local OsuSkinAtlas = {}

---@class rizu.skin.osu.OsuSkinAtlas.Asset
---@field name string?
---@field fallback string?
---@field animation boolean?
---@field group string?

---@class rizu.skin.osu.OsuSkinAtlas.Source
---@field image_data love.ImageData
---@field density number

---@class rizu.skin.osu.OsuSkinAtlas.PreparedGroup
---@field atlases love.ImageData[]
---@field locations {[string]: rizu.skin.ImageAtlasPacker.Location}
---@field densities {[string]: number}

---@class rizu.skin.osu.OsuSkinAtlas.Prepared
---@field groups {[string]: rizu.skin.osu.OsuSkinAtlas.PreparedGroup}
---@field standalone {[string]: rizu.skin.osu.OsuSkinAtlas.Source}
---@field grouped_paths {[string]: {[string]: boolean}} Group name to the paths it holds.

---Plain data, so it can cross a thread boundary.
---@class rizu.skin.osu.OsuSkinAtlas.Request
---@field file_map {[string]: string} Lowercase skin asset path to full path.
---@field fallback_file_map {[string]: string}
---@field fallback_archive string?
---@field assets rizu.skin.osu.OsuSkinAtlas.Asset[]
---@field texture_limit integer?
---@field atlas_limit integer

---@type {[string]: fs.ZipFilesystem}
local archive_cache = {}

---@param resource any
function OsuSkinAtlas.release(resource)
	if resource and resource.release then
		pcall(resource.release, resource)
	end
end
local release_resource = OsuSkinAtlas.release

---@param archive_path string
---@return fs.ZipFilesystem?
function OsuSkinAtlas.getArchive(archive_path)
	local archive = archive_cache[archive_path]
	if not archive then
		local content = love.filesystem.read(archive_path)
		if content then
			archive = ZipFilesystem(content)
			archive_cache[archive_path] = archive
		end
	end
	return archive
end

---@param path string
---@return number
function OsuSkinAtlas.getDensity(path)
	return path:lower():match("@2x%.png$") and 2 or 1
end

---@param name string
---@param maps {[string]: string}[]
---@return string?
function OsuSkinAtlas.findAsset(name, maps)
	if type(name) ~= "string" or name == "" then return nil end
	name = name:gsub("\\", "/"):gsub("^/+", ""):lower()
	local stem = name:gsub("%.png$", "")
	for _, map in ipairs(maps) do
		for _, candidate in ipairs({stem .. "@2x.png", stem .. ".png"}) do
			local path = map[candidate]
			if path then return path end
		end
	end
end

---@param base string
---@param file_map {[string]: string}
---@return {index: integer, path: string}[]
function OsuSkinAtlas.findAnimationAssets(base, file_map)
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

---Reads and decodes a skin file, or a file inside the fallback archive (paths prefixed with its name).
---@param fs fs.IFilesystem
---@param fallback_archive string?
---@return fun(path: string): love.ImageData?
function OsuSkinAtlas.newImageDataLoader(fs, fallback_archive)
	return function(path)
		---@type fs.IFilesystem?
		local read_fs = fs
		local read_path = path
		if fallback_archive and path:sub(1, #fallback_archive + 1) == fallback_archive .. "/" then
			read_fs, read_path = OsuSkinAtlas.getArchive(fallback_archive), path:sub(#fallback_archive + 2)
		end
		if not read_fs then return nil end
		local ok_read, content = pcall(read_fs.read, read_fs, read_path)
		if not ok_read or not content then return nil end
		local ok_file, file_data = pcall(love.filesystem.newFileData, content, path)
		if not ok_file then return nil end
		local ok_data, data = pcall(love.image.newImageData, file_data)
		release_resource(file_data)
		return ok_data and data or nil
	end
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

---@param prepared rizu.skin.osu.OsuSkinAtlas.Prepared
function OsuSkinAtlas.releasePrepared(prepared)
	for _, group in pairs(prepared.groups) do
		for _, data in ipairs(group.atlases) do release_resource(data) end
	end
	for _, source in pairs(prepared.standalone) do release_resource(source.image_data) end
end

---Decode, crop and pack. Device limits are supplied by the caller in the request.
---@param request rizu.skin.osu.OsuSkinAtlas.Request
---@param load_image_data fun(path: string): love.ImageData?
---@return rizu.skin.osu.OsuSkinAtlas.Prepared
function OsuSkinAtlas.prepare(request, load_image_data)
	local file_map, fallback_file_map = request.file_map, request.fallback_file_map
	local texture_limit = request.texture_limit
	local prepared = {groups = {}, standalone = {}, grouped_paths = {}} ---@type rizu.skin.osu.OsuSkinAtlas.Prepared
	local sources = {} ---@type {[string]: rizu.skin.osu.OsuSkinAtlas.Source|false}
	local groups = {} ---@type {[string]: {[string]: rizu.skin.osu.OsuSkinAtlas.Source}}
	---@param path string
	---@return rizu.skin.osu.OsuSkinAtlas.Source?
	local function decode(path)
		local cached = sources[path]
		if cached ~= nil then return cached or nil end
		local data = load_image_data(path)
		if not data then sources[path] = false; return end
		local source = {image_data = data, density = OsuSkinAtlas.getDensity(path)}
		sources[path] = source
		source.image_data = crop_image_data(data, texture_limit)
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
			for _, asset in ipairs(OsuSkinAtlas.findAnimationAssets(name, map)) do paths[#paths + 1] = asset.path end
			if #paths > 0 then return paths end
		end
		local path = OsuSkinAtlas.findAsset(name, {map})
		return path and {path} or {}
	end
	---@param asset rizu.skin.osu.OsuSkinAtlas.Asset
	local function add_asset(asset)
		local group_name = asset.group or "standalone"
		local group = groups[group_name] or {}
		groups[group_name] = group
		local names = {} ---@type string[]
		if asset.name then names[#names + 1] = asset.name end
		if asset.fallback and asset.fallback ~= asset.name then names[#names + 1] = asset.fallback end
		for _, map in ipairs({file_map, fallback_file_map}) do
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
		for _, asset in ipairs(request.assets) do add_asset(asset) end
		local pixel = love.image.newImageData(1, 1)
		local source = {image_data = pixel, density = 1}
		sources["\0white"] = source
		pixel:setPixel(0, 0, 1, 1, 1, 1)
		groups.playfield = groups.playfield or {}
		groups.playfield["\0white"] = source
		local packer = ImageAtlasPacker()
		local limit = math.min(request.atlas_limit, texture_limit or request.atlas_limit)
		packer.max_atlas_width, packer.max_atlas_height = limit, limit
		for name, entries in pairs(groups) do
			local input = {} ---@type {[string]: love.ImageData}
			local densities = {} ---@type {[string]: number}
			prepared.grouped_paths[name] = {}
			local oversized = {} ---@type string[]
			for path, entry in pairs(entries) do
				prepared.grouped_paths[name][path] = true
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
					local device_limit = texture_limit or ImageAtlasPacker.max_atlas_width
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
		OsuSkinAtlas.releasePrepared(prepared)
		error(err, 0)
	end
	return prepared
end

return OsuSkinAtlas
