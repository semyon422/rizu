local class = require("class")

---@class rizu.build.Context
---@operator call: rizu.build.Context
---@field fs fs.IFilesystem
---@field shell rizu.build.IShell
---@field downloader rizu.build.IDownloader
---@field target rizu.build.Target
---@field root string
local Context = class()

---@param fs fs.IFilesystem
---@param shell rizu.build.IShell
---@param downloader rizu.build.IDownloader
---@param target rizu.build.Target
---@param root string
function Context:new(fs, shell, downloader, target, root)
	self.fs = fs
	self.shell = shell
	self.downloader = downloader
	self.target = target
	self.root = root
end

return Context
