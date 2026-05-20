local ChartLocation = require("chart.format.notechart.ChartLocation")
local path_util = require("path_util")
local class = require("class")

---@class rizu.library.Finder
---@operator call: rizu.library.Finder
local Finder = class()

---@param fs fs.IFilesystem
function Finder:new(fs)
	self.fs = fs
end

---@param dir string?
---@return string? parent
---@return string? name
local function get_dir_name(dir)
	if not dir then
		return
	end
	local a, b = dir:match("^(.*)/(.-)$")
	if a and b then
		return a, b
	end
	return nil, dir
end
Finder.get_dir_name = get_dir_name

---@private
---@param prefix string?
---@param dir string?
function Finder:lookupAsync(prefix, dir)
	print("scan dir", prefix, dir)
	local prefix_dir = path_util.join(prefix, dir)

	local items = self.fs:getDirectoryItems(prefix_dir)
	local dir_info = self.fs:getInfo(prefix_dir)
	if not dir_info then
		local a, b = get_dir_name(dir)
		coroutine.yield("not_found", a, b, nil)
		return
	end

	---@type string[]
	local all_items = {}

	-- Phase 1: Check for direct chart files (like .osu, .bms, .sph)
	-- If a directory contains these, it's considered a "chart set"
	local has_related = false
	for _, item in ipairs(items) do
		local info = self.fs:getInfo(path_util.join(prefix, dir, item))
		if info and info.type == "file" and ChartLocation:isRelated(item) then
			if not has_related then
				has_related = true
				local a, b = get_dir_name(dir)
				coroutine.yield("related_dir", a, b, dir_info.modtime)
			end
			coroutine.yield("related", dir, item, info.modtime)
			table.insert(all_items, item)
		end
	end

	-- If we found related files, we stop here for this directory (don't treat as container)
	if has_related then
		coroutine.yield("related_all", dir, all_items, dir_info.modtime)
		return
	end

	-- Phase 2: Check for unrelated container files (like .ojn, .sm)
	-- These files themselves act as chart sets
	local has_unrelated = false
	for _, item in ipairs(items) do
		local info = self.fs:getInfo(path_util.join(prefix, dir, item))
		if info and info.type == "file" and ChartLocation:isUnrelated(item) then
			if not has_unrelated then
				has_unrelated = true
				local a, b = get_dir_name(dir)
				coroutine.yield("unrelated_dir", a, b, dir_info.modtime)
			end
			coroutine.yield("unrelated", dir, item, info.modtime)
			table.insert(all_items, item)
		end
	end

	if has_unrelated then
		coroutine.yield("unrelated_all", dir, all_items, dir_info.modtime)
		return
	end

	-- Phase 3: Pure directory scanning
	-- If no charts were found, recurse into subdirectories
	local a, b = get_dir_name(dir)
	coroutine.yield("directory_dir", a, b, dir_info.modtime)

	---@type string[]
	local subdirs_to_scan = {}
	for _, item in ipairs(items) do
		local info = self.fs:getInfo(path_util.join(prefix, dir, item))
		if info and (info.type == "directory" or info.type == "symlink") then
			-- The consumer can return 'false' to skip scanning this subdirectory
			if coroutine.yield("directory", dir, item, info.modtime) then
				table.insert(subdirs_to_scan, item)
			end
			table.insert(all_items, item)
		end
	end

	coroutine.yield("directory_all", dir, all_items, dir_info.modtime)

	for _, item in ipairs(subdirs_to_scan) do
		self:lookupAsync(prefix, path_util.join(dir, item))
	end
end

---@param prefix string?
---@param dir string?
---@return fun(): string, string, string, integer
function Finder:iter(prefix, dir)
	return coroutine.wrap(function()
		self:lookupAsync(prefix, dir)
	end)
end

return Finder
