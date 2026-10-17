local MusicDb = require("chart.format.iidx.MusicDb")
local path_util = require("path_util")

---@class chart.iidx.CatalogData
---@field dbs chart.iidx.CatalogMusicDb[]
---@field songs chart.iidx.MusicDbEntry[]
---@field by_id {[integer]: chart.iidx.MusicDbEntry}

---@class chart.iidx.Catalog
local Catalog = {}

local music_data_names = {"music_data.bin", "music_omni.bin"}

---@param fs fs.IFilesystem
---@param info_path string
---@return string[]
local function get_music_data_names(fs, info_path)
	---@type string[]
	local names = {}
	for _, name in ipairs(music_data_names) do
		if fs:getInfo(path_util.join(info_path, name)) then
			names[#names + 1] = name
		end
	end
	return names
end

---@class chart.iidx.InfoDbPath
---@field dir string
---@field name string

---@class chart.iidx.CatalogMusicDb: chart.iidx.MusicDb
---@field info_dir string
---@field source_name string

---@param fs fs.IFilesystem
---@param prefix string
---@return chart.iidx.InfoDbPath[]
local function get_info_dbs(fs, prefix)
	local info_root = path_util.join(prefix, "info")
	---@type chart.iidx.InfoDbPath[]
	local dbs = {}
	for _, item in ipairs(fs:getDirectoryItems(info_root)) do
		local info_path = path_util.join(info_root, item)
		local info = fs:getInfo(info_path)
		if info and info.type == "directory" then
			for _, name in ipairs(get_music_data_names(fs, info_path)) do
				dbs[#dbs + 1] = {dir = item, name = name}
			end
		end
	end
	table.sort(dbs, function(a, b)
		if a.dir ~= b.dir then
			return a.dir < b.dir
		end
		return a.name < b.name
	end)
	return dbs
end

---@param fs fs.IFilesystem
---@param prefix string
---@return boolean
function Catalog.isLocation(fs, prefix)
	if not fs:getInfo(path_util.join(prefix, "sound")) then
		return false
	end
	return #get_info_dbs(fs, prefix) > 0
end

---@param fs fs.IFilesystem
---@param prefix string
---@return chart.iidx.CatalogData?
---@return string?
function Catalog.load(fs, prefix)
	local info_dbs = get_info_dbs(fs, prefix)
	if #info_dbs == 0 then
		return nil, "IIDX music database not found"
	end

	---@type chart.iidx.CatalogMusicDb[]
	local dbs = {}
	for _, info_db in ipairs(info_dbs) do
		local path = path_util.join(prefix, "info", info_db.dir, info_db.name)
		local data, err = fs:read(path)
		if not data then
			return nil, err
		end
		local db = MusicDb.parse(data)
		---@cast db chart.iidx.CatalogMusicDb
		db.info_dir = info_db.dir
		db.source_name = info_db.name
		table.insert(dbs, db)
	end
	table.sort(dbs, function(a, b)
		if a.version ~= b.version then
			return a.version > b.version
		end
		if a.source_name ~= b.source_name then
			return a.source_name == "music_omni.bin"
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
