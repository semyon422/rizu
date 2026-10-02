local SkinResourceContext = require("rizu.skin.SkinResourceContext")

---@class rizu.skin.SkinResourceRequest : rizu.skin.SkinResourceContext.Options
---@field assets rizu.skin.SkinResourceRequest.Asset[] Only explicitly requested images are decoded.

---@class rizu.skin.SkinResourceRequest.Asset
---@field name string Logical resource name.
---@field path string Root-relative asset path.
---@field root string? Defaults to "skin"; fallback selection is performed by the caller.
---@field optional boolean? Missing/corrupt optional images are omitted and recorded in errors.

---@class rizu.skin.SkinDecodedResources
---@field images {[string]: love.ImageData} Owned CPU images, keyed by resolved path.
---@field assets {[string]: string} Logical name to resolved path; aliases share ownership.
---@field errors {[string]: string} Optional decode failures by resolved path.

---@class rizu.skin.SkinInstalledResources
---@field images {[string]: love.Image} Owned GPU images, keyed by resolved path.
---@field assets {[string]: love.Image} Logical name to image; aliases do not own another reference.
---@field errors {[string]: string}

---@class rizu.skin.SkinResourceLoader.DecodeEntry
---@field path string
---@field asset rizu.skin.SkinResourceRequest.Asset
---@field required boolean
---@field names string[]

---@class rizu.skin.SkinResourceLoader
local SkinResourceLoader = {}

---Idempotent. Also use this when discarding a late/cancelled worker result.
---@param resources rizu.skin.SkinDecodedResources?
function SkinResourceLoader.releaseDecoded(resources)
	if not resources then return end
	for path, data in pairs(resources.images) do
		data:release()
		resources.images[path] = nil
	end
	resources.assets = {}
end

---Idempotent. Rendering components borrow these images and must not release them.
---@param resources rizu.skin.SkinInstalledResources?
function SkinResourceLoader.releaseInstalled(resources)
	if not resources then return end
	for path, image in pairs(resources.images) do
		image:release()
		resources.images[path] = nil
	end
	resources.assets = {}
end

---Worker-compatible CPU phase. Expected failures are returned, not raised through the pool.
---@param request rizu.skin.SkinResourceRequest Plain data; no game, renderer, functions, or metatables.
---@param fs fs.IFilesystem
---@param decode (fun(context: rizu.skin.SkinResourceContext, path: string, root: string?): love.ImageData)? Test seam.
---@return rizu.skin.SkinDecodedResources?
---@return string?
function SkinResourceLoader.decode(request, fs, decode)
	local result = {images = {}, assets = {}, errors = {}} ---@type rizu.skin.SkinDecodedResources
	local ok, err = xpcall(function()
		local context = SkinResourceContext(fs, request)
		local entries = {} ---@type rizu.skin.SkinResourceLoader.DecodeEntry[]
		local by_path = {} ---@type {[string]: rizu.skin.SkinResourceLoader.DecodeEntry}
		local names = {} ---@type {[string]: boolean}
		for _, asset in ipairs(request.assets) do
			assert(type(asset.name) == "string" and asset.name ~= "", "resource name is required")
			assert(not names[asset.name], "duplicate resource name: " .. asset.name)
			names[asset.name] = true
			local path = context:resolvePath(asset.path, asset.root)
			local entry = by_path[path]
			if not entry then
				entry = {path = path, asset = asset, required = false, names = {}}
				by_path[path] = entry
				entries[#entries + 1] = entry
			end
			entry.required = entry.required or not asset.optional
			entry.names[#entry.names + 1] = asset.name
		end
		for _, entry in ipairs(entries) do
			local asset = entry.asset
			local decoded, data = pcall(decode or context.loadImageData, context, asset.path, asset.root)
			if decoded and data then
				result.images[entry.path] = data
				for _, name in ipairs(entry.names) do result.assets[name] = entry.path end
			else
				local message = ("skin %s, asset %s: %s"):format(request.skin_path, entry.path, tostring(data))
				assert(not entry.required, message)
				result.errors[entry.path] = message
			end
		end
	end, debug.traceback)
	if not ok then
		SkinResourceLoader.releaseDecoded(result)
		return nil, tostring(err)
	end
	return result
end

---Main-thread phase. Always consumes decoded ownership, even if upload fails.
---No partial image set is returned on failure.
---@param decoded rizu.skin.SkinDecodedResources
---@param upload (fun(data: love.ImageData): love.Image)? Test seam.
---@return rizu.skin.SkinInstalledResources?
---@return string?
function SkinResourceLoader.install(decoded, upload)
	local result = {images = {}, assets = {}, errors = decoded.errors} ---@type rizu.skin.SkinInstalledResources
	local ok, err = xpcall(function()
		for path, data in pairs(decoded.images) do
			local uploaded, image = pcall(upload or love.graphics.newImage, data)
			assert(uploaded and image, ("could not upload skin asset %s: %s"):format(path, tostring(image)))
			result.images[path] = image
			data:release()
			decoded.images[path] = nil
		end
		for name, path in pairs(decoded.assets) do
			result.assets[name] = assert(result.images[path], "decoded resource has no image: " .. path)
		end
	end, debug.traceback)
	SkinResourceLoader.releaseDecoded(decoded)
	if not ok then
		SkinResourceLoader.releaseInstalled(result)
		return nil, tostring(err)
	end
	return result
end

---The pool dumps this function: dependencies must be required inside the worker.
---@param request rizu.skin.SkinResourceRequest
---@return rizu.skin.SkinDecodedResources?
---@return string?
local function decodeWorker(request)
	require("love.filesystem")
	require("love.image")
	local LoveFilesystem = require("fs.LoveFilesystem")
	local Loader = require("rizu.skin.SkinResourceLoader") --[[@as rizu.skin.SkinResourceLoader]]
	return Loader.decode(request, LoveFilesystem())
end

---The caller must consume the future even after cancellation, releasing late data.
---@param request rizu.skin.SkinResourceRequest
---@return thread.Future
function SkinResourceLoader.startAsync(request)
	local thread = require("thread")
	return thread.future(decodeWorker)(request)
end

---Yields a main-thread coroutine; it does not block the game loop.
---@param future thread.Future
---@return rizu.skin.SkinDecodedResources?
---@return string?
function SkinResourceLoader.waitAsync(future)
	return require("thread").wait(future)
end

return SkinResourceLoader
