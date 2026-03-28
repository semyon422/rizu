local class = require("class")

---@class rizu.build.IDownloader
---@operator call: rizu.build.IDownloader
local IDownloader = class()

---@param url string
---@param dest string
---@return boolean success
function IDownloader:download(url, dest)
	error("not implemented")
end

return IDownloader
