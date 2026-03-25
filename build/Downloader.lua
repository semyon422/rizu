local class = require("class")
local IDownloader = require("build.IDownloader")

---@class build.Downloader: build.IDownloader
local Downloader = class(IDownloader)

function Downloader:download(url, dest)
	print("Downloading " .. url .. " to " .. dest)
	local cmd = string.format("curl -L %q -o %q", url, dest)
	return os.execute(cmd)
end

return Downloader
