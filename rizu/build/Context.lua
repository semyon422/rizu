local class = require("class")

---@class rizu.build.Context
---@operator call: rizu.build.Context
---@field fs fs.IFilesystem
---@field shell rizu.build.IShell
---@field downloader rizu.build.IDownloader
local Context = class()

---@param fs fs.IFilesystem
---@param shell rizu.build.IShell
---@param downloader rizu.build.IDownloader
function Context:new(fs, shell, downloader)
	self.fs = fs
	self.shell = shell
	self.downloader = downloader
end

return Context
