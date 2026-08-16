local Catalog = require("chart.format.iidx.Catalog")
local FileCacheGenerator = require("rizu.library.iidx.FileCacheGenerator")
local ChartfileReader = require("rizu.library.ChartfileReader")
local FakeTaskContext = require("rizu.library.tasks.FakeTaskContext")
local FakeFilesystem = require("fs.FakeFilesystem")
local Fixtures = require("chart.format.iidx.TestFixtures")
local digest = require("digest")
local sql_util = require("rdb.sql_util")

local test = {}

---@class test.FakeChartfileSet
---@field id integer?
---@field dir string
---@field name string
---@field location_id integer
---@field modified_at integer
---@field is_file boolean

---@class test.FakeChartfile
---@field id integer?
---@field name string
---@field set_id integer
---@field modified_at integer
---@field hash string?

---@class test.DeleteChartfileSetConds
---@field dir string?
---@field name__in string[]?
---@field location_id integer

---@class test.FakeChartfilesRepo
---@field nextSetId integer
---@field nextChartfileId integer
---@field sets test.FakeChartfileSet[]
---@field chartfiles test.FakeChartfile[]
---@field deleted test.DeleteChartfileSetConds[]
local FakeChartfilesRepo = {}
FakeChartfilesRepo.__index = FakeChartfilesRepo

---@return test.FakeChartfilesRepo
function FakeChartfilesRepo:new()
	return setmetatable({
		nextSetId = 1,
		nextChartfileId = 1,
		sets = {},
		chartfiles = {},
		deleted = {},
	}, self)
end

---@param dir string?
---@param name string
---@param location_id integer
---@return test.FakeChartfileSet?
function FakeChartfilesRepo:selectChartfileSet(dir, name, location_id)
	for _, set in ipairs(self.sets) do
		if set.dir == dir and set.name == name and set.location_id == location_id then
			return set
		end
	end
end

---@param set test.FakeChartfileSet
---@return test.FakeChartfileSet
function FakeChartfilesRepo:insertChartfileSet(set)
	set.id = self.nextSetId
	self.nextSetId = self.nextSetId + 1
	table.insert(self.sets, set)
	return set
end

function FakeChartfilesRepo:updateChartfileSet() end

---@param set_id integer
---@param name string
---@return test.FakeChartfile?
function FakeChartfilesRepo:selectChartfile(set_id, name)
	for _, chartfile in ipairs(self.chartfiles) do
		if chartfile.set_id == set_id and chartfile.name == name then
			return chartfile
		end
	end
end

---@param chartfile test.FakeChartfile
---@return test.FakeChartfile
function FakeChartfilesRepo:insertChartfile(chartfile)
	chartfile.id = self.nextChartfileId
	self.nextChartfileId = self.nextChartfileId + 1
	table.insert(self.chartfiles, chartfile)
	return chartfile
end

function FakeChartfilesRepo:updateChartfile() end

---@param location_id integer
---@param dir string?
---@return test.FakeChartfileSet[]
function FakeChartfilesRepo:selectChartfileSetsAtLocation(location_id, dir)
	local out = {}
	for _, set in ipairs(self.sets) do
		if set.location_id == location_id and (not dir or set.dir == dir) then
			table.insert(out, set)
		end
	end
	return out
end

---@param conds test.DeleteChartfileSetConds
function FakeChartfilesRepo:deleteChartfileSets(conds)
	table.insert(self.deleted, conds)
end

---@param conds {set_id: integer, name__notin: string[]?}
function FakeChartfilesRepo:deleteChartfiles(conds)
	for i = #self.chartfiles, 1, -1 do
		local chartfile = self.chartfiles[i]
		local should_delete = chartfile.set_id == conds.set_id
		if conds.name__notin then
			---@type {[string]: true}
			local keep = {}
			for index = 1, #conds.name__notin do
				keep[conds.name__notin[index]] = true
			end
			should_delete = should_delete and not keep[chartfile.name]
		end
		if should_delete then
			table.remove(self.chartfiles, i)
		end
	end
end

---@return fs.FakeFilesystem
local function create_fs()
	local fs = FakeFilesystem()
	fs:createDirectory("data")
	fs:createDirectory("data/info")
	fs:createDirectory("data/info/0")
	fs:createDirectory("data/sound")
	fs:write("data/info/0/music_data.bin", Fixtures.sampleMusicDb())
	fs:write("data/sound/01234.ifs", Fixtures.ifs(1234, Fixtures.sampleChart()))
	return fs
end

---@param t testing.T
function test.detects_iidx_location(t)
	local fs = create_fs()
	t:eq(Catalog.isLocation(fs, "data"), true)
	local catalog = assert(Catalog.load(fs, "data"))
	t:assert(catalog.by_id[1234])
	t:eq(catalog.by_id[1234].title, "Fixture Song")
end

---@param t testing.T
function test.scans_metadata_listed_ifs_files(t)
	local fs = create_fs()
	local repo = FakeChartfilesRepo:new()
	local generator = FileCacheGenerator(repo, fs, FakeTaskContext())

	assert(generator:scan(nil, 1, "data"))

	t:eq(#repo.sets, 1)
	t:eq(repo.sets[1].dir, "sound")
	t:eq(repo.sets[1].name, "01234.ifs")
	t:eq(repo.sets[1].is_file, false)
	t:eq(#repo.chartfiles, 1)
	t:eq(repo.chartfiles[1].name, "01234/01234.1")
	t:eq(generator:getSongByChartfileName("01234/01234.1").song_id, 1234)
end

---@param t testing.T
function test.scans_extracted_song_folder(t)
	local fs = create_fs()
	local chart_data = Fixtures.sampleChart()
	fs:remove("data/sound/01234.ifs")
	fs:createDirectory("data/sound/01234")
	fs:write("data/sound/01234/01234.1", chart_data)
	local repo = FakeChartfilesRepo:new()
	local generator = FileCacheGenerator(repo, fs, FakeTaskContext())

	assert(generator:scan(nil, 1, "data"))

	t:eq(repo.sets[1].name, "01234")
	t:eq(repo.sets[1].is_file, false)
	t:eq(repo.chartfiles[1].name, "01234.1")
	t:eq(generator:getSongByChartfileName("01234.1").song_id, 1234)
	t:eq(assert(ChartfileReader.read(fs, "data/sound/01234/01234.1")), chart_data)
end

---@param t testing.T
function test.ifs_takes_priority_over_extracted_folder(t)
	local fs = create_fs()
	fs:createDirectory("data/sound/01234")
	fs:write("data/sound/01234/01234.1", Fixtures.sampleChart())
	local repo = FakeChartfilesRepo:new()
	local generator = FileCacheGenerator(repo, fs, FakeTaskContext())

	assert(generator:scan(nil, 1, "data"))

	t:eq(repo.sets[1].name, "01234.ifs")
	t:eq(repo.chartfiles[1].name, "01234/01234.1")
end

---@param t testing.T
function test.p0_fallback(t)
	local fs = create_fs()
	fs:remove("data/sound/01234.ifs")
	fs:write("data/sound/01234-p0.ifs", Fixtures.ifs(1234, Fixtures.sampleChart()))
	local repo = FakeChartfilesRepo:new()
	local generator = FileCacheGenerator(repo, fs, FakeTaskContext())

	assert(generator:scan(nil, 1, "data"))

	t:eq(repo.sets[1].name, "01234-p0.ifs")
	t:eq(repo.sets[1].is_file, false)
	t:eq(repo.chartfiles[1].name, "01234/01234.1")
	t:eq(generator:getSongByChartfileName("01234/01234.1").song_id, 1234)
end

---@param t testing.T
function test.cleanup_missing_metadata_files(t)
	local fs = create_fs()
	local repo = FakeChartfilesRepo:new()
	table.insert(repo.sets, {
		id = repo.nextSetId,
		dir = "sound",
		name = "99999.ifs",
		location_id = 1,
		modified_at = 0,
		is_file = false,
	})
	repo.nextSetId = repo.nextSetId + 1
	local generator = FileCacheGenerator(repo, fs, FakeTaskContext())

	assert(generator:scan(nil, 1, "data"))

	t:eq(#repo.deleted, 1)
	t:tdeq(repo.deleted[1].name__in, {"99999.ifs"})
end

---@param t testing.T
function test.cleanup_stale_ifs_chartfile_inside_current_set(t)
	local fs = create_fs()
	local repo = FakeChartfilesRepo:new()
	table.insert(repo.sets, {
		id = repo.nextSetId,
		dir = "sound",
		name = "01234.ifs",
		location_id = 1,
		modified_at = 0,
		is_file = true,
	})
	repo.nextSetId = repo.nextSetId + 1
	table.insert(repo.chartfiles, {
		id = repo.nextChartfileId,
		name = "01234.ifs",
		set_id = 1,
		modified_at = 0,
		hash = "old",
	})
	repo.nextChartfileId = repo.nextChartfileId + 1
	local generator = FileCacheGenerator(repo, fs, FakeTaskContext())

	assert(generator:scan(nil, 1, "data"))

	t:eq(repo.sets[1].is_file, false)
	t:eq(#repo.chartfiles, 1)
	t:eq(repo.chartfiles[1].name, "01234/01234.1")
end

---@param t testing.T
function test.invalidates_extracted_chart_hash_when_chart_changes(t)
	local fs = create_fs()
	fs:remove("data/sound/01234.ifs")
	fs:createDirectory("data/sound/01234")
	fs:write("data/sound/01234/01234.1", Fixtures.sampleChart())
	local repo = FakeChartfilesRepo:new()
	table.insert(repo.sets, {
		id = repo.nextSetId,
		dir = "sound",
		name = "01234",
		location_id = 1,
		modified_at = 0,
		is_file = false,
	})
	repo.nextSetId = repo.nextSetId + 1
	table.insert(repo.chartfiles, {
		id = repo.nextChartfileId,
		name = "01234.1",
		set_id = 1,
		modified_at = -1,
		hash = "cached",
	})
	repo.nextChartfileId = repo.nextChartfileId + 1
	local generator = FileCacheGenerator(repo, fs, FakeTaskContext())

	assert(generator:scan(nil, 1, "data"))

	t:eq(repo.chartfiles[1].hash, sql_util.NULL)
	t:eq(repo.chartfiles[1].modified_at, 0)
end

---@param t testing.T
function test.preserves_existing_chart_hash_when_archive_modtime_changes(t)
	local fs = create_fs()
	local repo = FakeChartfilesRepo:new()
	table.insert(repo.sets, {
		id = repo.nextSetId,
		dir = "sound",
		name = "01234.ifs",
		location_id = 1,
		modified_at = -1,
		is_file = false,
	})
	repo.nextSetId = repo.nextSetId + 1
	table.insert(repo.chartfiles, {
		id = repo.nextChartfileId,
		name = "01234/01234.1",
		set_id = 1,
		modified_at = -1,
		hash = "cached",
	})
	repo.nextChartfileId = repo.nextChartfileId + 1
	local generator = FileCacheGenerator(repo, fs, FakeTaskContext())

	assert(generator:scan(nil, 1, "data"))

	t:eq(repo.chartfiles[1].hash, "cached")
	t:eq(repo.chartfiles[1].modified_at, 0)
end

---@param t testing.T
function test.virtual_chartfile_reads_extracted_chart_data(t)
	local fs = create_fs()
	local chart_data = Fixtures.sampleChart()
	local data = assert(ChartfileReader.read(fs, "data/sound/01234.ifs/01234/01234.1"))

	t:eq(data, chart_data)
	t:eq(digest.hash("md5", data, true), digest.hash("md5", chart_data, true))
	t:assert(ChartfileReader.getInfo(fs, "data/sound/01234.ifs/01234/01234.1"))
end

return test
