local PackageDownloader = require("rizu.pkg.PackageDownloader")

local test = {}

---@class rizu.pkg.FakeHeadersForPackageDownloader
---@field values {[string]: string}
local FakeHeaders = {}
FakeHeaders.__index = FakeHeaders

---@param name string
---@return string?
function FakeHeaders:get(name)
	return self.values[name]
end

---@param values {[string]: string}?
---@return rizu.pkg.FakeHeadersForPackageDownloader
local function new_headers(values)
	return setmetatable({values = values or {}}, FakeHeaders)
end

---@param t testing.T
function test.download_uses_network_service(t)
	local old_love = love
	---@type string
	local written_path
	---@type {data: string, filename: string}
	local written_data
	love = {
		filesystem = {
			newFileData = function(data, filename)
				return {data = data, filename = filename}
			end,
			write = function(path, filedata)
				written_path = path
				written_data = filedata
				return true
			end,
		},
	}

	---@type string
	local requested_url
	---@type rizu.NetworkStatusHttpOptions
	local requested_options
	local network = {
		download = function(_, url, options)
			requested_url = url
			requested_options = options
			return {
				status = 200,
				headers = new_headers({
					["Content-Disposition"] = "attachment; filename=\"cool skin.zip\"",
				}),
				body = "zipdata",
			}
		end,
	}

	local ok, err = pcall(function()
		local downloader = PackageDownloader("userdata/pkg", network --[[@as any]])
		local pkg_info = {url = "https://example.test/package"}

		downloader:download(pkg_info)

		t:eq(requested_url, "https://example.test/package")
		t:eq(requested_options.chunk_size, 64 * 1024)
		t:eq(pkg_info.isDownloading, false)
		t:eq(pkg_info.status, "Done! Restart the game.")
		t:eq(written_path, "userdata/pkg/cool skin.zip")
		t:tdeq(written_data, {data = "zipdata", filename = "cool skin.zip"})
	end)
	love = old_love
	if not ok then
		error(err, 0)
	end
end

---@param t testing.T
function test.download_reports_network_error(t)
	local network = {
		download = function()
			return nil, "timeout"
		end,
	}
	local downloader = PackageDownloader("userdata/pkg", network --[[@as any]])
	local pkg_info = {url = "https://example.test/package.zip"}

	downloader:download(pkg_info)

	t:eq(pkg_info.isDownloading, false)
	t:eq(pkg_info.status, "timeout")
end

---@param t testing.T
function test.download_reports_http_error(t)
	local network = {
		download = function()
			return {
				status = 500,
				headers = new_headers(),
				body = "error",
			}
		end,
	}
	local downloader = PackageDownloader("userdata/pkg", network --[[@as any]])
	local pkg_info = {url = "https://example.test/package.zip"}

	downloader:download(pkg_info)

	t:eq(pkg_info.isDownloading, false)
	t:eq(pkg_info.status, "HTTP 500")
end

---@param t testing.T
function test.rejects_non_zip_download(t)
	local network = {
		download = function()
			return {
				status = 200,
				headers = new_headers(),
				body = "data",
			}
		end,
	}
	local downloader = PackageDownloader("userdata/pkg", network --[[@as any]])
	local pkg_info = {url = "https://example.test/readme.txt"}

	downloader:download(pkg_info)

	t:eq(pkg_info.isDownloading, false)
	t:eq(pkg_info.status, "Unsupported file type")
end

---@param t testing.T
function test.network_is_required(t)
	local ok, err = pcall(function()
		PackageDownloader("userdata/pkg")
	end)

	t:eq(ok, false)
	t:assert(tostring(err):find("network is required", 1, true))
end

return test
