local class = require("class")
local Path = require("Path")

---@class rizu.select.ILocationDirectoryOpener
---@field open fun(self: rizu.select.ILocationDirectoryOpener, location: rizu.library.Location, dir: string?)

---@class rizu.select.services.LocationDirectoryOpener: rizu.select.ILocationDirectoryOpener
---@operator call: rizu.select.services.LocationDirectoryOpener
local LocationDirectoryOpener = class()

---@param getSource? fun(): string
---@param getSourceBaseDirectory? fun(): string
---@param openURL? fun(url: string)
function LocationDirectoryOpener:new(getSource, getSourceBaseDirectory, openURL)
	self.getSource = getSource or love.filesystem.getSource
	self.getSourceBaseDirectory = getSourceBaseDirectory or love.filesystem.getSourceBaseDirectory
	self.openURL = openURL or love.system.openURL
end

---@param location rizu.library.Location
---@param dir string?
---@return string
function LocationDirectoryOpener:getPath(location, dir)
	local dir_path = Path(location.path)
	if dir then
		dir_path = dir_path .. Path(dir)
	end

	if not dir_path.absolute then
		local source = self.getSource()
		if source:find("^.+%.love$") then
			source = self.getSourceBaseDirectory()
		end
		dir_path = Path(source) .. dir_path
	end

	return tostring(dir_path)
end

---@param location rizu.library.Location
---@param dir string?
function LocationDirectoryOpener:open(location, dir)
	self.openURL(self:getPath(location, dir))
end

return LocationDirectoryOpener
