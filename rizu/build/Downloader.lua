local class = require("class")
local IDownloader = require("rizu.build.IDownloader")

---@class rizu.build.Downloader: rizu.build.IDownloader
---@operator call: rizu.build.Downloader
---@field shell rizu.build.IShell
local Downloader = class(IDownloader)

---@param shell rizu.build.IShell
function Downloader:new(shell)
	self.shell = shell
end

---@param url string
---@param dest string
---@return boolean
function Downloader:download(url, dest)
	print("Downloading " .. url .. " to " .. dest)
	local cmd = string.format("curl -fL --retry 3 --retry-all-errors %q -o %q", url, dest)
	self.shell:execute(cmd)
	return true
end

return Downloader
