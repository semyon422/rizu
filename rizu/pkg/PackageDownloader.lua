local class = require("class")
local thread = require("thread")
local path_util = require("path_util")
local http_util = require("web.http.util")
local fs_util = require("fs_util")
local pprint = require("pprint")

---@class rizu.PackageDownloader
---@operator call: rizu.PackageDownloader
local PackageDownloader = class()

---@param pkgs_path string
function PackageDownloader:new(pkgs_path)
	self.pkgs_path = pkgs_path
end

function PackageDownloader:download(pkg_info)
	print(("Downloading: %s"):format(pkg_info.url))
	pkg_info.status = "Downloading"

	pkg_info.isDownloading = true
	local data, code, headers, status_line = fs_util.downloadAsync(pkg_info.url)
	pkg_info.isDownloading = false

	if code == 302 then
		pprint(headers)
	end

	if not data then
		pkg_info.status = status_line
		return
	end

	local filename = pkg_info.url:match("^.+/(.-)$")
	for header, value in pairs(headers) do
		header = header:lower()
		if header == "content-disposition" then
			local cd = http_util.parse_content_disposition(value)
			filename = cd.filename or filename
		end
	end

	filename = path_util.fix_illegal(filename)

	print(("Downloaded: %s"):format(filename))
	if not filename:find("%.zip$") then
		pkg_info.status = "Unsupported file type"
		print("Unsupported file type")
		return
	end

	local filedata = love.filesystem.newFileData(data, filename)
	local path = path_util.join(self.pkgs_path, filename)
	love.filesystem.write(path, filedata)

	pkg_info.status = "Done! Restart the game."
end
PackageDownloader.download = thread.coro(PackageDownloader.download)

return PackageDownloader
