local class = require("class")
local path_util = require("path_util")
local ChartfileReader = require("rizu.library.ChartfileReader")

---@alias rizu.ResourceFormat "audio"|"image"|"video"|"ojm"|"s3p"|"2dx"

---@type {[rizu.ResourceFormat]: string[]}
local format_extensions = {
	audio = {"wav", "ogg", "mp3"},
	image = {"png", "bmp", "jpg"},
	video = {"mpg", "avi", "mp4", "mpeg", "wmv"},
	ojm = {"ojm"},
	s3p = {"s3p"},
	["2dx"] = {"2dx"},
}

---@type {[string]: rizu.ResourceFormat}
local extension_format = {}
for format, list in pairs(format_extensions) do
	for i = 1, #list do
		extension_format[list[i]] = format
	end
end

---@type {[string]: rizu.ResourceFormat}
local type_to_format = {
	sound = "audio",
	audio = "audio",
	image = "image",
	video = "video",
	ojm = "ojm",
	s3p = "s3p",
	["2dx"] = "2dx",
}

---@class rizu.ResourceFinder
---@operator call: rizu.ResourceFinder
local ResourceFinder = class()

---@param fs fs.IFilesystem
function ResourceFinder:new(fs)
	self.fs = fs
	self:reset()
end

function ResourceFinder:reset()
	---@type string[]
	self.paths = {}
	---@type {[string]: {lookup: {[string]: string}, stems: {[string]: {[string]: string}}}}
	self.path_files = {}
end

---@param path string
function ResourceFinder:addPath(path)
	path = assert(path, "missing path")
	table.insert(self.paths, path)
	local files = self:getFilesRecursive(path)

	---@type {lookup: {[string]: string}, stems: {[string]: {[string]: string}}}
	local index = {
		lookup = {},
		stems = {},
	}

	for _, name_ext in ipairs(files) do
		local name_ext_lower = name_ext:lower()
		index.lookup[name_ext_lower] = name_ext

		local name, ext = path_util.name_ext(name_ext)
		if ext then
			local name_lower = name:lower()
			local ext_lower = ext:lower()
			if not index.stems[name_lower] then
				index.stems[name_lower] = {}
			end
			index.stems[name_lower][ext_lower] = name_ext
		end
	end

	self.path_files[path] = index
end

---@param path string
---@param list table?
---@param prefix string?
---@return string[]
function ResourceFinder:getFilesRecursive(path, list, prefix)
	list = list or {}
	prefix = prefix or ""

	if path:lower():match("%.ifs$") then
		local files = ChartfileReader.listArchive(self.fs, path) or {}
		for _, file in ipairs(files) do
			table.insert(list, file)
		end
		return list
	end

	for _, file in ipairs(self.fs:getDirectoryItems(path)) do
		local info = assert(self.fs:getInfo(path .. "/" .. file))
		if info.type == "directory" then
			self:getFilesRecursive(path .. "/" .. file, list, prefix .. file .. "/")
		else
			table.insert(list, prefix .. file)
		end
	end
	return list
end

---@param ext string?
---@return rizu.ResourceFormat?
function ResourceFinder:getFormat(ext)
	return ext and extension_format[ext:lower()]
end

---@param req_name_ext string
---@param format string?
---@return string?
function ResourceFinder:findFile(req_name_ext, format)
	req_name_ext = path_util.fix_separators(req_name_ext)
	req_name_ext = req_name_ext:gsub("^/", "")

	local req_name, req_ext = path_util.name_ext(req_name_ext)
	local inferred_format = self:getFormat(req_ext)

	format = inferred_format or type_to_format[format]
	if not format then
		return
	end

	local extensions = format_extensions[format]
	local req_name_ext_lower = req_name_ext:lower()
	local req_name_lower = req_name:lower()

	for _, path in ipairs(self.paths) do
		local req_path = path .. "/" .. req_name_ext
		if self.fs:getInfo(req_path) then
			return req_path
		end

		local index = self.path_files[path]
		if index then
			-- 1. Case-insensitive exact match
			local exact = index.lookup[req_name_ext_lower]
			if exact then
				return path .. "/" .. exact
			end

			-- 2. Match with format extensions
			local stem_match = index.stems[req_name_lower]
			if stem_match then
				for _, check_ext in ipairs(extensions) do
					local found = stem_match[check_ext] -- extensions in format_extensions are already lower
					if found then
						return path .. "/" .. found
					end
				end
			end
		end
	end
end

return ResourceFinder
