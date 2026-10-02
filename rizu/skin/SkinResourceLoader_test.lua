local Loader = require("rizu.skin.SkinResourceLoader")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@class rizu.skin.SkinResourceLoaderTest.Owned : love.ImageData, love.Image
---@field releases integer
---@field release fun(self: rizu.skin.SkinResourceLoaderTest.Owned)

---@return rizu.skin.SkinResourceLoaderTest.Owned
local function owned()
	---@param self rizu.skin.SkinResourceLoaderTest.Owned
	local function release(self) self.releases = self.releases + 1 end
	return {releases = 0, release = release}
end

---@param assets rizu.skin.SkinResourceRequest.Asset[]
---@return rizu.skin.SkinResourceRequest
local function request(assets)
	return {
		skin_path = "example.skin.lua", directory_path = "skin", files = {"unused.png"},
		roots = {fallback = {directory_path = "fallback", files = {"a.png"}}},
		assets = assets,
	}
end

---@param t testing.T
function test.decodes_only_requests_and_deduplicates_resolved_paths(t)
	local count = 0
	local data = {} ---@type {[string]: rizu.skin.SkinResourceLoaderTest.Owned}
	local decoded = assert(Loader.decode(request({
		{name = "note", path = "a.png"},
		{name = "alias", path = "./a.png"},
		{name = "fallback", path = "a.png", root = "fallback"},
	}), FakeFilesystem(), function(context, path, root)
		count = count + 1
		local image = owned()
		data[context:resolvePath(path, root)] = image
		return image
	end))
	t:eq(count, 2)
	t:eq(decoded.assets.note, decoded.assets.alias)
	t:assert(decoded.assets.note ~= decoded.assets.fallback)
	local uploads = 0
	local installed = assert(Loader.install(decoded, function()
		uploads = uploads + 1
		return owned()
	end))
	t:eq(uploads, 2)
	t:eq(installed.assets.note, installed.assets.alias)
	for _, image in pairs(data) do t:eq(image.releases, 1) end
	local images = {installed.assets.note, installed.assets.fallback}
	---@cast images rizu.skin.SkinResourceLoaderTest.Owned[]
	Loader.releaseDecoded(decoded)
	Loader.releaseInstalled(installed)
	Loader.releaseInstalled(installed)
	for _, image in ipairs(images) do t:eq(image.releases, 1) end
end

---@param t testing.T
function test.decode_failure_releases_partial_data(t)
	local first = owned()
	local result, err = Loader.decode(request({
		{name = "first", path = "a.png"}, {name = "bad", path = "bad.png"},
	}), FakeFilesystem(), function(_, path)
		if path == "bad.png" then error("corrupt image") end
		return first
	end)
	t:eq(result, nil)
	t:eq(first.releases, 1)
	t:assert(assert(err):find("skin/bad.png", 1, true))
	t:assert(assert(err):find("example.skin.lua", 1, true))
end

---@param t testing.T
function test.optional_alias_does_not_hide_required_failure(t)
	local count = 0
	local result = Loader.decode(request({
		{name = "optional", path = "bad.png", optional = true},
		{name = "required", path = "./bad.png"},
	}), FakeFilesystem(), function()
		count = count + 1
		error("bad")
	end)
	t:eq(result, nil)
	t:eq(count, 1)
	local optional = assert(Loader.decode(request({
		{name = "optional", path = "bad.png", optional = true},
	}), FakeFilesystem(), function() error("bad") end))
	t:eq(optional.assets.optional, nil)
	t:assert(optional.errors["skin/bad.png"])
end

---@param t testing.T
function test.upload_failure_consumes_all_cpu_data_and_releases_gpu_data(t)
	local a, b, gpu = owned(), owned(), owned()
	local decoded = {images = {a = a, b = b}, assets = {a = "a", b = "b"}, errors = {}}
	local uploads = 0
	local result, err = Loader.install(decoded, function()
		uploads = uploads + 1
		if uploads == 2 then error("upload failed") end
		return gpu
	end)
	t:eq(result, nil)
	t:assert(assert(err):find("upload failed", 1, true))
	t:eq(a.releases, 1)
	t:eq(b.releases, 1)
	t:eq(gpu.releases, 1)
	Loader.releaseDecoded(decoded)
	t:eq(a.releases, 1)
end

---@param t testing.T
function test.discarded_result_is_released_without_upload(t)
	local data = owned()
	local result = assert(Loader.decode(request({{name = "a", path = "a.png"}}),
		FakeFilesystem(), function() return data end))
	Loader.releaseDecoded(result)
	Loader.releaseDecoded(result)
	t:eq(data.releases, 1)
end

---@param t testing.T
function test.empty_set_and_invalid_request(t)
	local empty = assert(Loader.decode(request({}), FakeFilesystem(), function()
		error("no images should be decoded")
	end))
	local installed = assert(Loader.install(empty, function() error("no uploads expected") end))
	t:eq(next(installed.images), nil)
	Loader.releaseInstalled(installed)
	local decoded = 0
	local invalid, err = Loader.decode(request({
		{name = "same", path = "a.png"}, {name = "same", path = "b.png"},
	}), FakeFilesystem(), function()
		decoded = decoded + 1
		return owned()
	end)
	t:eq(invalid, nil)
	t:assert(assert(err):find("duplicate resource name", 1, true))
	t:eq(decoded, 0)
end

return test
