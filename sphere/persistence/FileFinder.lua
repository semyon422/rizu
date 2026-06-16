local class = require("class")

local FileTypes = {
	audio = {"wav", "ogg", "mp3"},
	image = {"png", "bmp", "jpg"},
	video = {"mpg", "avi", "mp4", "mpeg", "wmv"},
	ojm = {"ojm"},
	s3p = {"s3p"},
	["2dx"] = {"2dx"},
}

local FileTypeMap = {}
for format, list in pairs(FileTypes) do
	for i = 1, #list do
		FileTypeMap[list[i]] = format
	end
end

---@class sphere.FileFinder
---@operator call: sphere.FileFinder
local FileFinder = class()

function FileFinder:new()
	self:reset()
end

function FileFinder:reset()
	self.paths = {}
	self.fileLists = {}
end

---@param fileName string
---@return string
---@return string?
local function removeExtension(fileName)
	local ext = fileName:match("%.([^%.]+)$")
	ext = ext and ext:lower()
	local format = FileTypeMap[ext]
	return format and fileName:sub(1, -#ext - 2) or fileName, format
end

---@param fileName string
---@return string?
function FileFinder:getType(fileName)
	local ext = fileName:match("%.([^%.]+)$")
	ext = ext and ext:lower()
	return FileTypeMap[ext]
end

---@param path string
function FileFinder:addPath(path)
	table.insert(self.paths, path)
end

---@param path string
---@param list table?
---@param prefix string?
---@return table
function FileFinder:getFileListRecursive(path, list, prefix)
	list = list or {}
	prefix = prefix or ""
	local files = love.filesystem.getDirectoryItems(path)
	for i = 1, #files do
		local info = love.filesystem.getInfo(path .. "/" .. files[i], "directory")
		if info then
			self:getFileListRecursive(path .. "/" .. files[i], list, prefix .. files[i] .. "/")
		else
			table.insert(list, prefix .. files[i])
		end
	end
	return list
end

---@param path string
---@return table
function FileFinder:getFileList(path)
	local fileLists = self.fileLists
	if fileLists[path] then
		return fileLists[path]
	end
	fileLists[path] = self:getFileListRecursive(path)
	return fileLists[path]
end

---@param fullFileName string?
---@param _fileType string?
---@return string?
function FileFinder:findFile(fullFileName, _fileType)
	if not fullFileName then
		return
	end

	if love.filesystem.getInfo(fullFileName) then
		return fullFileName
	end

	fullFileName = fullFileName:gsub("\\", "/")
	fullFileName = fullFileName:gsub("¥", "/")
	fullFileName = fullFileName:gsub("^/", "")
	local fileName, fileType = removeExtension(fullFileName)
	fileType = fileType or _fileType

	if not fileType then
		return
	end

	for _, path in ipairs(self.paths) do
		local filePath = path .. "/" .. fullFileName
		if love.filesystem.getInfo(filePath) then
			return filePath
		end
		local files = self:getFileList(path)
		for _, file in ipairs(files) do
			if file:lower() == fullFileName:lower() then
				return path .. "/" .. file
			end
		end
		for _, file in ipairs(files) do
			local trueFileName, trueFileType = removeExtension(file)
			if fileName:lower() == trueFileName:lower() and fileType == trueFileType then
				return path .. "/" .. file
			end
		end
	end
end

return FileFinder
