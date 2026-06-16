local MusicDb = require("chart.format.iidx.MusicDb")
local path_util = require("path_util")

---@class chart.iidx.CatalogData
---@field dbs chart.iidx.MusicDb[]
---@field songs chart.iidx.MusicDbEntry[]
---@field by_id {[integer]: chart.iidx.MusicDbEntry}

---@class chart.iidx.Catalog
local Catalog = {}

local music_data_name = "music_data.bin"

---@param fs fs.IFilesystem
---@param prefix string
---@return string[]
local function get_info_dirs(fs, prefix)
	local info_root = path_util.join(prefix, "info")
	local dirs = {}
	for _, item in ipairs(fs:getDirectoryItems(info_root)) do
		local path = path_util.join(info_root, item)
		local info = fs:getInfo(path)
		if info and info.type == "directory" and fs:getInfo(path_util.join(path, music_data_name)) then
			table.insert(dirs, item)
		end
	end
	table.sort(dirs)
	return dirs
end

---@param fs fs.IFilesystem
---@param prefix string
---@return boolean
function Catalog.isLocation(fs, prefix)
	if not fs:getInfo(path_util.join(prefix, "sound")) then
		return false
	end
	return #get_info_dirs(fs, prefix) > 0
end

---@param fs fs.IFilesystem
---@param prefix string
---@return chart.iidx.CatalogData?
---@return string?
function Catalog.load(fs, prefix)
	local dirs = get_info_dirs(fs, prefix)
	if #dirs == 0 then
		return nil, "music_data.bin not found"
	end

	local dbs = {}
	for _, dir in ipairs(dirs) do
		local path = path_util.join(prefix, "info", dir, music_data_name)
		local data, err = fs:read(path)
		if not data then
			return nil, err
		end
		local db = MusicDb.parse(data)
		db.info_dir = dir
		table.insert(dbs, db)
	end
	table.sort(dbs, function(a, b)
		if a.version ~= b.version then
			return a.version > b.version
		end
		return tostring(a.info_dir) > tostring(b.info_dir)
	end)

	local catalog = {
		dbs = dbs,
		songs = {},
		by_id = {},
	}
	---@cast catalog chart.iidx.CatalogData

	for _, db in ipairs(dbs) do
		for _, song in ipairs(db.songs) do
			if not catalog.by_id[song.song_id] then
				catalog.by_id[song.song_id] = song
				table.insert(catalog.songs, song)
			end
		end
	end
	table.sort(catalog.songs, function(a, b)
		return a.song_id < b.song_id
	end)

	return catalog
end

return Catalog
