local class = require("class")

---@class rizu.editor.EditorDropImport
---@operator call: rizu.editor.EditorDropImport
---@field fs fs.IFilesystem
---@field getTime fun(): integer
local EditorDropImport = class()

local supportedExtensions = {
	mp3 = true,
	ogg = true,
}

---@param fs fs.IFilesystem
---@param getTime (fun(): integer)?
function EditorDropImport:new(fs, getTime)
	self.fs = fs
	self.getTime = getTime or os.time
end

---@param file love.File
---@return string? path
function EditorDropImport:import(file)
	local sourcePath = file:getFilename():gsub("\\", "/")
	local sourceName, ext = sourcePath:match("^(.+)%.(.-)$")
	if not sourceName or not ext or not supportedExtensions[ext] then
		return
	end

	local audioName = sourceName:match("^.+/(.-)$") or sourceName
	local chartSetPath = ("userdata/charts/editor/%d %s"):format(self.getTime(), audioName)
	local path = ("%s/%s.%s"):format(chartSetPath, audioName, ext)

	self.fs:createDirectory(chartSetPath)
	assert(self.fs:write(path, file:read()))

	return path
end

return EditorDropImport
