local LoveFilesystem = require("fs.LoveFilesystem")
local ZipFilesystem = require("fs.ZipFilesystem")
local fs_util = require("fs.util")

local DlcExtractor = {}

---@param archive string
---@param path string
---@param target_fs fs.IFilesystem?
---@return boolean? success, string? error
function DlcExtractor.extract(archive, path, target_fs)
	local lfs = target_fs or LoveFilesystem()
	local data, err = lfs:read(archive)

	if not data then
		return nil, "Failed to read archive: " .. tostring(err)
	end

	local ok, zfs_or_err = pcall(ZipFilesystem --[[@as fun(): fs.ZipFilesystem]], data)
	if not ok then
		return nil, "Failed to load zip: " .. tostring(zfs_or_err)
	end

	---@cast zfs_or_err fs.ZipFilesystem
	
	-- Redundant nesting reduction logic
	local root_items = zfs_or_err:getDirectoryItems("")
	local source_path = ""
	
	-- Check if there's only one item at the root and it's a directory
	if #root_items == 1 then
		local item_name = root_items[1]
		local info = zfs_or_err:getInfo(item_name)
		if info and info.type == "directory" then
			source_path = item_name
		end
	end

	local ok, err = pcall(fs_util.copy, source_path, path, zfs_or_err, lfs)
	if not ok then
		return nil, "Extraction failed: " .. tostring(err)
	end

	return true
end

return DlcExtractor
