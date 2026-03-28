local class = require("class")

---@class build.Context
---@operator call: build.Context
---@field fs fs.IFilesystem
---@field shell build.IShell
---@field downloader build.IDownloader
---@field target build.Target
---@field root string
local Context = class()

---@param fs fs.IFilesystem
---@param shell build.IShell
---@param downloader build.IDownloader
---@param target build.Target
---@param root string
function Context:new(fs, shell, downloader, target, root)
	self.fs = fs
	self.shell = shell
	self.downloader = downloader
	self.target = target
	self.root = root
end

return Context
