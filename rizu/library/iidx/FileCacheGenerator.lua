local Catalog = require("chart.format.iidx.Catalog")
local class = require("class")
local path_util = require("path_util")
local table_util = require("table_util")
local sql_util = require("rdb.sql_util")

---@class rizu.library.iidx.FileCacheGenerator
---@operator call: rizu.library.iidx.FileCacheGenerator
---@field chartfilesRepo rizu.library.ChartfilesRepo
---@field fs fs.IFilesystem
---@field taskContext rizu.library.ITaskContext
---@field songsByChartfileName {[string]: chart.iidx.MusicDbEntry}
local FileCacheGenerator = class()

---@class rizu.library.iidx.SongStorage
---@field name string
---@field chartfile_name string
---@field set_modified_at integer
---@field chart_modified_at integer
---@field invalidate_hash boolean

---@param chartfilesRepo rizu.library.ChartfilesRepo
---@param fs fs.IFilesystem
---@param taskContext rizu.library.ITaskContext
function FileCacheGenerator:new(chartfilesRepo, fs, taskContext)
	self.chartfilesRepo = chartfilesRepo
	self.fs = fs
	self.taskContext = taskContext
	self.songsByChartfileName = {}
end

---@param root_dir string?
---@param location_id integer
---@param location_prefix string
---@return chart.iidx.CatalogData?
---@return string?
function FileCacheGenerator:scan(root_dir, location_id, location_prefix)
	self.songsByChartfileName = {}
	if root_dir then
		root_dir = nil
	end

	local catalog, err = Catalog.load(self.fs, location_prefix)
	if not catalog then
		return nil, err
	end
	print(("iidx scan: loaded catalog, %d metadata songs"):format(#catalog.songs))
	self.taskContext:startStage("scanning", #catalog.songs)

	---@type {[string]: true}
	local current_names = {}
	local discovered_count = 0
	---@type chart.iidx.MusicDbEntry
	local song
	for i = 1, #catalog.songs do
		song = catalog.songs[i]
		local storage = self:getSongStorage(location_prefix, song.song_id)
		if storage then
			discovered_count = discovered_count + 1
			current_names[storage.name] = true
			self.songsByChartfileName[storage.chartfile_name] = song
			self:processChartfileSet({
				dir = "sound",
				name = storage.name,
				modified_at = storage.set_modified_at,
				is_file = false,
				location_id = location_id,
			}, storage.chartfile_name, storage.chart_modified_at, storage.invalidate_hash)
			self.taskContext:advance(1)
		end
		if i % 250 == 0 then
			local label = ("%d/%d metadata songs"):format(i, #catalog.songs)
			print("iidx scan:", label)
			self.taskContext:report(label)
		end
		if i % 1000 == 0 then
			self.taskContext:dbCommit()
			self.taskContext:dbBegin()
		end
	end
	print(("iidx scan: discovered %d present chart sets"):format(discovered_count))
	self.taskContext:report(("%d/%d metadata songs"):format(#catalog.songs, #catalog.songs))

	local names_to_delete = {}
	local sets = self.chartfilesRepo:selectChartfileSetsAtLocation(location_id, "sound")
	for _, set in ipairs(sets) do
		if not current_names[set.name] then
			table.insert(names_to_delete, set.name)
		end
	end
	for _, slice in ipairs(table_util.slices(names_to_delete, 1024)) do
		self.chartfilesRepo:deleteChartfileSets({
			dir = "sound",
			name__in = slice,
			location_id = location_id,
		})
	end

	return catalog
end

---@param location_prefix string
---@param song_id integer
---@return rizu.library.iidx.SongStorage?
function FileCacheGenerator:getSongStorage(location_prefix, song_id)
	local song_dir = ("%05d"):format(song_id)
	local archive_names = {song_dir .. ".ifs", song_dir .. "-p0.ifs"}
	for _, name in ipairs(archive_names) do
		local info = self.fs:getInfo(path_util.join(location_prefix, "sound", name))
		if info and info.type == "file" then
			return {
				name = name,
				chartfile_name = path_util.join(song_dir, song_dir .. ".1"),
				set_modified_at = info.modtime,
				chart_modified_at = info.modtime,
				invalidate_hash = false,
			}
		end
	end

	local folder_names = {song_dir, song_dir .. "-p0"}
	for _, name in ipairs(folder_names) do
		local folder_path = path_util.join(location_prefix, "sound", name)
		local folder_info = self.fs:getInfo(folder_path)
		if folder_info and folder_info.type == "directory" then
			local chartfile_name = song_dir .. ".1"
			local chart_info = self.fs:getInfo(path_util.join(folder_path, chartfile_name))
			if chart_info and chart_info.type == "file" then
				return {
					name = name,
					chartfile_name = chartfile_name,
					set_modified_at = folder_info.modtime,
					chart_modified_at = chart_info.modtime,
					invalidate_hash = true,
				}
			end
		end
	end
end

---@param chartfile_set sea.ClientChartfileSetInsert
---@param chartfile_name string
---@param chart_modified_at integer
---@param invalidate_hash boolean
---@return sea.ClientChartfileSet
function FileCacheGenerator:processChartfileSet(chartfile_set, chartfile_name, chart_modified_at, invalidate_hash)
	local existing = self.chartfilesRepo:selectChartfileSet(
		chartfile_set.dir,
		chartfile_set.name,
		chartfile_set.location_id
	)

	if existing then
		if existing.modified_at ~= chartfile_set.modified_at or existing.is_file ~= chartfile_set.is_file then
			existing.modified_at = chartfile_set.modified_at
			existing.is_file = chartfile_set.is_file
			self.chartfilesRepo:updateChartfileSet(existing)
		end
		self:processChartfile(existing.id, chartfile_name, chart_modified_at, invalidate_hash)
		self.chartfilesRepo:deleteChartfiles({set_id = existing.id, name__notin = {chartfile_name}})
		return existing
	end

	local set = self.chartfilesRepo:insertChartfileSet(chartfile_set)
	self:processChartfile(set.id, chartfile_name, chart_modified_at, invalidate_hash)
	return set
end

---@param set_id integer
---@param name string
---@param modified_at integer
---@param invalidate_hash boolean
function FileCacheGenerator:processChartfile(set_id, name, modified_at, invalidate_hash)
	local chartfile = self.chartfilesRepo:selectChartfile(set_id, name)
	if not chartfile then
		self.chartfilesRepo:insertChartfile({
			name = name,
			modified_at = modified_at,
			set_id = set_id,
		})
	elseif chartfile.modified_at ~= modified_at then
		chartfile.modified_at = modified_at
		if invalidate_hash or not chartfile.hash then
			chartfile.hash = sql_util.NULL
		end
		self.chartfilesRepo:updateChartfile(chartfile)
	end
end

---@param name string
---@return chart.iidx.MusicDbEntry?
function FileCacheGenerator:getSongByChartfileName(name)
	return self.songsByChartfileName[name]
end

return FileCacheGenerator
