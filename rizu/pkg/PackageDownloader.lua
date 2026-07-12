local class = require("class")
local thread = require("thread")
local path_util = require("path_util")
local http_util = require("web.http.util")

---@class rizu.PackageDownloader
---@operator call: rizu.PackageDownloader
---@field network rizu.NetworkService
local PackageDownloader = class()

---@param pkgs_path string
---@param network rizu.NetworkService
function PackageDownloader:new(pkgs_path, network)
	self.pkgs_path = pkgs_path
	self.network = assert(network, "network is required")
end

function PackageDownloader:download(pkg_info)
	print(("Downloading: %s"):format(pkg_info.url))
	pkg_info.status = "Downloading"

	pkg_info.isDownloading = true
	local res, err = self.network:download(pkg_info.url, {
		chunk_size = 64 * 1024,
	})
	pkg_info.isDownloading = false

	if not res then
		pkg_info.status = err
		return
	end

	if res.status >= 400 then
		pkg_info.status = "HTTP " .. res.status
		return
	end

	local filename = pkg_info.url:match("^.+/(.-)$")
	local cd_header = res.headers:get("Content-Disposition")
	if cd_header then
		local cd = http_util.parse_content_disposition(cd_header)
		filename = cd.filename or filename
	end

	filename = path_util.fix_illegal(filename)

	print(("Downloaded: %s"):format(filename))
	if not filename:find("%.zip$") then
		pkg_info.status = "Unsupported file type"
		print("Unsupported file type")
		return
	end

	local filedata = love.filesystem.newFileData(res.body, filename)
	local path = path_util.join(self.pkgs_path, filename)
	love.filesystem.write(path, filedata)

	pkg_info.status = "Done! Restart the game."
end
PackageDownloader.download = thread.coro(PackageDownloader.download)

return PackageDownloader
