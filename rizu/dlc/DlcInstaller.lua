local class = require("class")
local path_util = require("path_util")
local DlcExtractor = require("rizu.dlc.DlcExtractor")

---@class rizu.dlc.IDlcInstallFilesystem
---@field getInfo fun(path: string): table?
---@field createDirectory fun(path: string): boolean?
---@field write fun(path: string, data: string): boolean?

---@class rizu.dlc.IDlcExtractor
---@field extract fun(archive_path: string, extract_path: string): boolean?, string?

---@class rizu.dlc.DlcInstaller
---@operator call: rizu.dlc.DlcInstaller
---@field fs rizu.dlc.IDlcInstallFilesystem
---@field extractor rizu.dlc.IDlcExtractor
local DlcInstaller = class()

---@param fs rizu.dlc.IDlcInstallFilesystem?
---@param extractor rizu.dlc.IDlcExtractor?
function DlcInstaller:new(fs, extractor)
	self.fs = fs or love.filesystem
	self.extractor = extractor or DlcExtractor
end

---@param _type rizu.dlc.DlcType
---@param metadata table?
---@return string
function DlcInstaller:getBaseDir(_type, metadata)
	if _type == "pack" then
		return "userdata/charts/packs"
	elseif _type == "file" and metadata and metadata.dest_dir then
		return metadata.dest_dir
	end

	return "userdata/charts/downloads"
end

---@param archive_path string
---@param extract_path string
---@return boolean? success
---@return string? error
function DlcInstaller:extract(archive_path, extract_path)
	local ok, err = self.extractor.extract(archive_path, extract_path)
	if not ok then
		return nil, "Extraction failed: " .. (err or "unknown error")
	end

	return true
end

---@param _id string|number
---@param _type rizu.dlc.DlcType
---@param data string
---@param filename string
---@param metadata table?
---@return boolean? success
---@return string? error
function DlcInstaller:install(_id, _type, data, filename, metadata)
	local base_dir = self:getBaseDir(_type, metadata)
	local fs = self.fs

	if not fs.getInfo(base_dir) then
		fs.createDirectory(base_dir)
	end

	local filepath = path_util.join(base_dir, filename)
	fs.write(filepath, data)

	if _type == "set" and filename:match("%.osz$") then
		local extract_dir = filename:match("^(.+)%.osz$")
		local extract_path = path_util.join(base_dir, extract_dir)
		return self:extract(filepath, extract_path)
	elseif _type == "pack" and filename:match("%.zip$") then
		local extract_dir = filename:match("^(.+)%.zip$")
		local extract_path = path_util.join(base_dir, extract_dir)
		return self:extract(filepath, extract_path)
	end

	return true
end

return DlcInstaller
