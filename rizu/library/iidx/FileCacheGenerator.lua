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

---@class rizu.library.iidx.ChartfileSetDraft
---@field dir string
---@field name string
---@field modified_at integer
---@field is_file boolean
---@field location_id integer

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

	local current_names = {}
	local discovered_count = 0
	for i, song in ipairs(catalog.songs) do
		local archive_name = self:getArchiveName(location_prefix, song.song_id)
		if archive_name then
			discovered_count = discovered_count + 1
			local chartfile_name = self:getChartfileName(song.song_id)
			current_names[archive_name] = true
			self.songsByChartfileName[chartfile_name] = song
			self:processChartfileSet({
				dir = "sound",
				name = archive_name,
				modified_at = self:getModifiedAt(location_prefix, archive_name),
				is_file = false,
				location_id = location_id,
			}, chartfile_name)
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
	print(("iidx scan: discovered %d present chart archives"):format(discovered_count))
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
---@return string?
function FileCacheGenerator:getArchiveName(location_prefix, song_id)
	local base = ("%05d.ifs"):format(song_id)
	if self.fs:getInfo(path_util.join(location_prefix, "sound", base)) then
		return base
	end
	local p0 = ("%05d-p0.ifs"):format(song_id)
	if self.fs:getInfo(path_util.join(location_prefix, "sound", p0)) then
		return p0
	end
end

---@param song_id integer
---@return string
function FileCacheGenerator:getChartfileName(song_id)
	local dir = ("%05d"):format(song_id)
	return path_util.join(dir, dir .. ".1")
end

---@param location_prefix string
---@param name string
---@return integer
function FileCacheGenerator:getModifiedAt(location_prefix, name)
	local info = assert(self.fs:getInfo(path_util.join(location_prefix, "sound", name)))
	return info.modtime
end

---@param chartfile_set rizu.library.iidx.ChartfileSetDraft
---@param chartfile_name string
---@return sea.ClientChartfileSet
function FileCacheGenerator:processChartfileSet(chartfile_set, chartfile_name)
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
		self:processChartfile(existing.id, chartfile_name, chartfile_set.modified_at)
		self.chartfilesRepo:deleteChartfiles({set_id = existing.id, name__notin = {chartfile_name}})
		return existing
	end

	local set = self.chartfilesRepo:insertChartfileSet(chartfile_set)
	self:processChartfile(set.id, chartfile_name, set.modified_at)
	return set
end

---@param set_id integer
---@param name string
---@param modified_at integer
function FileCacheGenerator:processChartfile(set_id, name, modified_at)
	local chartfile = self.chartfilesRepo:selectChartfile(set_id, name)
	if not chartfile then
		self.chartfilesRepo:insertChartfile({
			name = name,
			modified_at = modified_at,
			set_id = set_id,
		})
	elseif chartfile.modified_at ~= modified_at then
		chartfile.modified_at = modified_at
		if not chartfile.hash then
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
