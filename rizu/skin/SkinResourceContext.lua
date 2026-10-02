local class = require("class")
local Path = require("Path")

---@class rizu.skin.SkinResourceRoot
---@field directory_path string
---@field files string[]

---@class rizu.skin.SkinResourceContext.Options
---@field skin_path string
---@field directory_path string
---@field files string[]?
---@field roots {[string]: rizu.skin.SkinResourceRoot}?

---@class rizu.skin.SkinResourceContext
---@operator call: rizu.skin.SkinResourceContext
---@field fs fs.IFilesystem?
---@field skin_path string
---@field directory_path string
---@field files string[] Sorted skin-relative paths; not a list of images to decode.
---@field roots {[string]: rizu.skin.SkinResourceRoot}
local SkinResourceContext = class()

---Normalizes an asset path relative to a selected root.
---@param path string
---@return string
function SkinResourceContext.normalizePath(path)
	assert(type(path) == "string", "resource path must be a string")
	local parsed = Path(path)
	assert(not parsed.absolute, "resource path must be relative")
	-- Path.normalize() drops unmatched '..'; validate before normalizing so
	-- an invalid request cannot silently resolve to a different asset.
	local depth = 0
	for _, part in ipairs(parsed.parts) do
		if part.name == ".." then
			assert(depth > 0, "resource path escapes its root")
			depth = depth - 1
		elseif part.name ~= "." then
			depth = depth + 1
		end
	end
	return tostring(parsed:normalize():toFile())
end

---@param directory string
---@param files string[]?
---@return rizu.skin.SkinResourceRoot
local function makeRoot(directory, files)
	local sorted = {} ---@type string[]
	local seen = {} ---@type {[string]: boolean}
	for _, path in ipairs(files or {}) do
		local normalized = SkinResourceContext.normalizePath(path)
		if normalized ~= "" and not seen[normalized] then
			seen[normalized] = true
			sorted[#sorted + 1] = normalized
		end
	end
	table.sort(sorted)
	return {directory_path = tostring(Path(directory):normalize():toFile()), files = sorted}
end

---@param fs fs.IFilesystem?
---@param options rizu.skin.SkinResourceContext.Options
function SkinResourceContext:new(fs, options)
	self.fs = fs
	self.skin_path = options.skin_path
	local root = makeRoot(options.directory_path or "", options.files)
	self.directory_path = root.directory_path
	self.files = root.files
	self.roots = {skin = root}
	for name, root in pairs(options.roots or {}) do
		assert(name ~= "skin", "the primary skin root cannot be replaced")
		self.roots[name] = makeRoot(root.directory_path, root.files)
	end
end

---@param relative_path string
---@param root_name string?
---@return string path
function SkinResourceContext:resolvePath(relative_path, root_name)
	local root = assert(self.roots[root_name or "skin"], "unknown skin resource root: " .. tostring(root_name))
	local path = SkinResourceContext.normalizePath(relative_path)
	assert(path ~= "", "resource path must name a file")
	return tostring(Path(root.directory_path) .. Path(path))
end

---Returns a sorted list of root-relative files beneath a directory.
---@param directory string?
---@param root_name string?
---@return string[]
function SkinResourceContext:getFiles(directory, root_name)
	local root = assert(self.roots[root_name or "skin"], "unknown skin resource root: " .. tostring(root_name))
	local prefix = SkinResourceContext.normalizePath(directory or "")
	local files = {} ---@type string[]
	for _, path in ipairs(root.files) do
		if prefix == "" or path:sub(1, #prefix + 1) == prefix .. "/" then
			files[#files + 1] = path
		end
	end
	return files
end

---CPU-only decoding. The caller owns the returned ImageData.
---@param relative_path string
---@param root_name string?
---@return love.ImageData
function SkinResourceContext:loadImageData(relative_path, root_name)
	local path = self:resolvePath(relative_path, root_name)
	local ok, result = pcall(function()
		local content, err = assert(self.fs, "resource filesystem is required"):read(path)
		assert(content, err or "could not read image")
		local file_data = love.filesystem.newFileData(content, path)
		local decoded, image_data = pcall(love.image.newImageData, file_data)
		file_data:release()
		assert(decoded, image_data)
		return image_data
	end)
	assert(ok, ("skin %s, asset %s: %s"):format(self.skin_path, path, tostring(result)))
	return result
end

---Creates a plain snapshot suitable for worker transport; never sends this context or its fs.
---@param assets rizu.skin.SkinResourceRequest.Asset[]
---@return rizu.skin.SkinResourceRequest
function SkinResourceContext:createRequest(assets)
	local roots = {} ---@type {[string]: rizu.skin.SkinResourceRoot}
	local files = {} ---@type string[]
	for i, path in ipairs(self.files) do files[i] = path end
	for name, root in pairs(self.roots) do
		if name ~= "skin" then
			local copied = {} ---@type string[]
			for i, path in ipairs(root.files) do copied[i] = path end
			roots[name] = {directory_path = root.directory_path, files = copied}
		end
	end
	local requests = {} ---@type rizu.skin.SkinResourceRequest.Asset[]
	for i, asset in ipairs(assets) do
		requests[i] = {name = asset.name, path = asset.path, root = asset.root, optional = asset.optional}
	end
	return {skin_path = self.skin_path, directory_path = self.directory_path,
		files = files, roots = roots, assets = requests}
end

return SkinResourceContext
