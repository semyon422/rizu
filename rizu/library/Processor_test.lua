local Processor = require("rizu.library.Processor")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local FakeFilesystem = require("fs.FakeFilesystem")
local path_util = require("path_util")
local FunctionTimer = require("time.FunctionTimer")

local test = {}
local timer = FunctionTimer(function()
	return 0
end)

function test.computeLocation_sph(t)
	local fs = FakeFilesystem()
	function fs:mount() return true end
	function fs:unmount() return true end

	-- Create a fake location and a minimal SPH chart
	fs:createDirectory("/userdata/charts/test_pack")

	-- Minimal SPH needs 2 lines in # notes for tempo calculation
	local sph_content = [[
# metadata
input 4key
# notes
1000 =0
1000 =1
]]
	fs:write("/userdata/charts/test_pack/chart.sph", sph_content)

	local db = Database(LinuxFilesystem())
	db:load(":memory:")

	local processor = Processor(db, fs, "/fake/root", timer)

	-- Use location 1 which is created by Locations:load() internally
	processor.locations:load()
	local loc = processor.locationsRepo:selectLocationById(1)
	t:assert(loc, "Default location should be created")

	-- Test computing the cache
	processor:computeLocation(nil, 1)

	local count = processor.chartfilesRepo:countChartfiles()
	t:eq(count, 1, "Should have cached 1 chartfile")

	local chartfile = processor.chartfilesRepo:selectChartfile(1, "chart.sph")
	---@cast chartfile -?
	t:assert(chartfile, "chart.sph should be in the repository")
	t:assert(chartfile.hash, "chart.sph should be hashed")

	local chartmetas = processor.chartsRepo:countChartmetas()
	t:eq(chartmetas, 1, "Should have 1 chartmeta")

	local chartdiffs = processor.chartsRepo:countChartdiffs()
	t:eq(chartdiffs, 1, "Should have 1 chartdiff")

	db:unload()
end

---@param t testing.T
function test.getChartsByHash(t)
	local fs = FakeFilesystem()
	local db = Database(LinuxFilesystem())
	db:load(":memory:")

	local processor = Processor(db, fs, "/fake/root", timer)
	processor.locations:load()

	local loc = processor.locationsRepo:selectLocationById(1)
	t:assert(loc, "Default location should exist")
	---@cast loc -?

	-- Set up a chart in the filesystem
	local dir = "test_pack"
	local name = "chart.sph"
	local full_dir = path_util.join(loc.path, dir)
	fs:createDirectory(full_dir)

	local sph_content = [[
# metadata
title Test Chart
artist Test Artist
input 4key
# notes
1000 =0
1000 =1
]]
	fs:write(path_util.join(full_dir, name), sph_content)

	-- 1. Run computeLocation to cache the chart and get its hash
	processor:computeLocation(nil, 1)

	local chartfile = processor.chartfilesRepo:selectChartfile(1, name)
	---@cast chartfile -?
	t:assert(chartfile.hash, "Chartfile should be cached and hashed")

	-- 2. Test getChartsByHash
	local charts, err = processor:getChartsByHash(chartfile.hash)
	t:assert(charts, "Should return charts: " .. tostring(err))
	---@cast charts -?
	t:eq(#charts, 1, "Should return exactly one chart")

	local chart = charts[1]
	t:eq(tostring(chart.inputMode), "4key", "Should have correct input mode")
	t:eq(#chart.notes.notes, 2, "Should have 2 notes")

	-- 3. Test non-existent hash
	local missing, err2 = processor:getChartsByHash("non-existent")
	t:eq(missing, nil)
	---@cast err2 -?
	t:assert(err2:find("chartfile not found"), "Should return error for missing hash")

	db:unload()
end

return test
