local RemoteAssetCache = require("rizu.library.RemoteAssetCache")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param t testing.T
function test.keeps_files_under_the_url_path(t)
	local cache = RemoteAssetCache({}, FakeFilesystem(), "cache")
	t:eq(cache:getPath("https://cdn.test/backgrounds/v2/a.avif?x=1"), "cache/backgrounds/v2/a.avif")
	t:eq(cache:getPath("https://cdn.test/../a"), nil)
	t:eq(cache:getPath("https://cdn.test/"), nil)
end

---@param t testing.T
function test.downloads_a_file_once(t)
	local fs = FakeFilesystem()
	local requested = 0
	local cache = RemoteAssetCache({
		download = function()
			requested = requested + 1
			return {status = 200, body = "image"}
		end,
	}, fs, "cache")

	t:eq(cache:get("https://cdn.test/a/b.avif"), "image")
	t:eq(cache:get("https://cdn.test/a/b.avif"), "image")
	t:eq(requested, 1)
	t:eq(fs:read("cache/a/b.avif"), "image")
end

---@param t testing.T
function test.reports_http_errors(t)
	local cache = RemoteAssetCache({
		download = function() return {status = 404, body = ""} end,
	}, FakeFilesystem(), "cache")
	local body, err = cache:get("https://cdn.test/a")
	t:eq(body, nil)
	t:eq(err, "HTTP 404")
end

return test
