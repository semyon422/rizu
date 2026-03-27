local class = require("class")
local IDownloader = require("build.IDownloader")

---@class build.Downloader: build.IDownloader
local Downloader = class(IDownloader)

local function normalize_status(ok, status, code)
	if type(ok) == "number" then
		return ok == 0, ok
	end
	if ok == true then
		return true, 0
	end
	if ok == false then
		return false, code or status or 1
	end
	return false, code or status or 1
end

function Downloader:download(url, dest)
	print("Downloading " .. url .. " to " .. dest)
	local cmd = string.format("curl -fL --retry 3 --retry-all-errors %q -o %q", url, dest)
	local ok, status, code = os.execute(cmd)
	local success, exit_code = normalize_status(ok, status, code)
	if not success then
		error(string.format("Download failed (exit %s): %s", tostring(exit_code), url), 2)
	end
	return true
end

return Downloader
