local class = require("class")
local Path = require("Path")

---@class rizu.preview.BackgroundFinder
---@operator call: rizu.preview.BackgroundFinder
local BackgroundFinder = class()

local extensions = {png = true, jpg = true, jpeg = true, tga = true, bmp = true}

---@param fs fs.IFilesystem
function BackgroundFinder:new(fs)
	self.fs = fs
end

---@param path string
---@return boolean
function BackgroundFinder:isImage(path)
	local ext = Path(path):getExtension()
	if not ext or not extensions[ext:lower()] then return false end
	local info = self.fs:getInfo(path)
	return info ~= nil and info.type ~= "directory"
end

---@param requested string
---@return string?
function BackgroundFinder:find(requested)
	local path = Path(requested):normalize()
	if self:isImage(tostring(path)) then return tostring(path) end
	local info = self.fs:getInfo(tostring(path))
	local directory
	if info and info.type == "directory" then
		path = path:toDirectory()
		directory = path
	else
		directory = path:trimLast()
	end
	local original = path:isFile() and path:getName(true)
	local found, fallback
	for _, filename in ipairs(self.fs:getDirectoryItems(tostring(directory))) do
		local file = Path(filename)
		local ext = file:getExtension()
		if ext and extensions[ext:lower()] then
			local name = file:getName(true):lower()
			if not (name:find("cdtitle") or name:find("banner") or name == "bn") then
				if name:find("background") or name:find("bg") or original and name:find(original, 1, true) then
					found = filename
					break
				end
				fallback = filename
			end
		end
	end
	if not found and not fallback then return end
	local result = tostring(directory .. Path(found or fallback))
	if self:isImage(result) then return result end
end

return BackgroundFinder
