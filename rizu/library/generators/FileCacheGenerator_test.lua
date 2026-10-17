local path_util = require("path_util")
local FileCacheGenerator = require("rizu.library.generators.FileCacheGenerator")
local ChartfilesRepo = require("rizu.library.repos.ChartfilesRepo")
local LocationsRepo = require("rizu.library.repos.LocationsRepo")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local Finder = require("rizu.library.Finder")
local FakeTaskContext = require("rizu.library.tasks.FakeTaskContext")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local function setup_db()
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	return db
end

function test.rel_root(t)
	local db = setup_db()
	local chartRepo = ChartfilesRepo(db.models)
	local locationsRepo = LocationsRepo(db.models)
	locationsRepo:insertLocation({id = 1, path = "prefix", name = "test", is_relative = false, is_internal = false})

	local fs = FakeFilesystem()
	fs:createDirectory("prefix/chartset")
	fs:write("prefix/chartset/chart1.osu", "content")
	fs:write("prefix/chartset/chart2.osu", "content")

	local ncf = Finder(fs)
	local context = FakeTaskContext()
	local fcg = FileCacheGenerator(chartRepo, ncf, context)
	
	fcg:scan("chartset", 1, "prefix")

	local sets = chartRepo:selectChartfileSetsAtLocation(1)
	t:eq(#sets, 1)
	t:eq(sets[1].name, "chartset")

	local charts = chartRepo:selectUnhashedChartfiles(nil, 1, sets[1].id)
	t:eq(#charts, 2)
	
	db:unload()
end

function test.unrel_root(t)
	local db = setup_db()
	local chartRepo = ChartfilesRepo(db.models)
	local locationsRepo = LocationsRepo(db.models)
	locationsRepo:insertLocation({id = 1, path = "prefix", name = "test", is_relative = false, is_internal = false})

	local fs = FakeFilesystem()
	fs:createDirectory("prefix/charts")
	fs:write("prefix/charts/chart1.ojn", "content")
	fs:write("prefix/charts/chart2.ojn", "content")

	local ncf = Finder(fs)
	local context = FakeTaskContext()
	local fcg = FileCacheGenerator(chartRepo, ncf, context)
	
	fcg:scan("charts", 1, "prefix")

	local sets = chartRepo:selectChartfileSetsAtLocation(1)
	t:eq(#sets, 2)
	t:eq(sets[1].name, "chart1.ojn")
	t:eq(sets[2].name, "chart2.ojn")

	db:unload()
end

function test.incremental_update(t)
	local db = setup_db()
	local chartRepo = ChartfilesRepo(db.models)
	local locationsRepo = LocationsRepo(db.models)
	locationsRepo:insertLocation({id = 1, path = "prefix", name = "test", is_relative = false, is_internal = false})

	local fs = FakeFilesystem()
	fs:setTime(1000)
	fs:createDirectory("prefix/chartset")
	fs:write("prefix/chartset/chart1.osu", "content")
	
	local ncf = Finder(fs)
	local context = FakeTaskContext()
	local fcg = FileCacheGenerator(chartRepo, ncf, context)
	
	-- First scan
	fcg:scan("chartset", 1, "prefix")
	local cf = chartRepo:selectChartfile(1, "chart1.osu")
	t:eq(cf.modified_at, 1000)
	
	-- Update file time
	fs:setTime(2000)
	fs:write("prefix/chartset/chart1.osu", "new content")
	
	-- Second scan
	cf.hash = "old_hash"
	chartRepo:updateChartfile(cf)
	
	fcg:scan("chartset", 1, "prefix")
	local updated_cf = chartRepo:selectChartfile(1, "chart1.osu")
	t:eq(updated_cf.modified_at, 2000)
	t:eq(updated_cf.hash, nil, "Hash should be reset on modtime change")
	
	db:unload()
end

function test.directory_cleanup(t)
	local db = setup_db()
	local chartRepo = ChartfilesRepo(db.models)
	local locationsRepo = LocationsRepo(db.models)
	locationsRepo:insertLocation({id = 1, path = "prefix", name = "test", is_relative = false, is_internal = false})

	local fs = FakeFilesystem()
	fs:createDirectory("prefix/pack1")
	fs:write("prefix/pack1/chart.osu", "content")
	fs:createDirectory("prefix/pack2")
	fs:write("prefix/pack2/chart.osu", "content")
	
	local ncf = Finder(fs)
	local context = FakeTaskContext()
	local fcg = FileCacheGenerator(chartRepo, ncf, context)
	
	-- Initial scan
	fcg:scan(nil, 1, "prefix")
	t:eq(chartRepo:countChartfileSets({location_id = 1}), 2)
	
	-- Delete a directory from filesystem
	fs:remove("prefix/pack2/chart.osu")
	fs:remove("prefix/pack2")
	
	-- Scan again (must be full scan for cleanup)
	fcg:scan(nil, 1, "prefix")
	t:eq(chartRepo:countChartfileSets({location_id = 1}), 1)
	t:eq(chartRepo:countChartfiles({location_id = 1}), 1)
	
	db:unload()
end

function test.complex(t)
	local db = setup_db()
	local chartRepo = ChartfilesRepo(db.models)
	local locationsRepo = LocationsRepo(db.models)
	locationsRepo:insertLocation({id = 1, path = "prefix", name = "test", is_relative = false, is_internal = false})

	local fs = FakeFilesystem()
	-- Directory root/osucharts/chartset1 -> 2 osu files
	fs:createDirectory("prefix/root/osucharts/chartset1")
	fs:write("prefix/root/osucharts/chartset1/a.osu", "content")
	fs:write("prefix/root/osucharts/chartset1/b.osu", "content")
	
	-- Directory root/osucharts/chartset2 -> 2 osu files
	fs:createDirectory("prefix/root/osucharts/chartset2")
	fs:write("prefix/root/osucharts/chartset2/a.osu", "content")
	fs:write("prefix/root/osucharts/chartset2/b.osu", "content")
	
	-- Directory root/jamcharts -> 2 ojn files
	fs:createDirectory("prefix/root/jamcharts")
	fs:write("prefix/root/jamcharts/a.ojn", "content")
	fs:write("prefix/root/jamcharts/b.ojn", "content")

	local ncf = Finder(fs)
	local context = FakeTaskContext()
	local fcg = FileCacheGenerator(chartRepo, ncf, context)

	fcg:scan("root", 1, "prefix")

	-- Expecting 4 chartfile sets:
	-- 1. root/osucharts/chartset1
	-- 2. root/osucharts/chartset2
	-- 3. a.ojn (in root/jamcharts)
	-- 4. b.ojn (in root/jamcharts)
	t:eq(chartRepo:countChartfileSets({location_id = 1}), 4)
	-- Total 6 chartfiles (2 + 2 + 1 + 1)
	t:eq(chartRepo:countChartfiles({location_id = 1}), 6)

	db:unload()
end

function test.ojn_cleanup(t)
	local db = setup_db()
	local chartRepo = ChartfilesRepo(db.models)
	local locationsRepo = LocationsRepo(db.models)
	locationsRepo:insertLocation({id = 1, path = "prefix", name = "test", is_relative = false, is_internal = false})

	local fs = FakeFilesystem()
	fs:createDirectory("prefix/charts")
	fs:write("prefix/charts/chart1.ojn", "content")
	fs:write("prefix/charts/chart2.ojn", "content")
	
	local ncf = Finder(fs)
	local context = FakeTaskContext()
	local fcg = FileCacheGenerator(chartRepo, ncf, context)
	
	-- Initial scan
	fcg:scan("charts", 1, "prefix")
	t:eq(chartRepo:countChartfileSets({location_id = 1}), 2)
	t:eq(chartRepo:countChartfiles({location_id = 1}), 2)
	
	-- Delete one OJN file
	fs:remove("prefix/charts/chart2.ojn")
	
	-- Scan the same directory again
	fcg:scan("charts", 1, "prefix")
	
	-- Should have only 1 set left
	t:eq(chartRepo:countChartfileSets({location_id = 1}), 1)
	local sets = chartRepo:selectChartfileSetsAtLocation(1)
	t:eq(sets[1].name, "chart1.ojn")
	
	db:unload()
end

return test
