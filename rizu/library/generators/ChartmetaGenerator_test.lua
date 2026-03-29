local ChartmetaGenerator = require("rizu.library.generators.ChartmetaGenerator")
local ChartfilesRepo = require("rizu.library.repos.ChartfilesRepo")
local LocationsRepo = require("rizu.library.repos.LocationsRepo")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local digest = require("digest")

local test = {}

local function setup_db()
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	return db
end

function test.all(t)
	local db = setup_db()
	local chartfilesRepo = ChartfilesRepo(db.models)
	local chartsRepo = ChartsRepo(db.models)
	local locationsRepo = LocationsRepo(db.models)

	locationsRepo:insertLocation({id = 1, path = "charts", name = "game", is_relative = true, is_internal = true})

	-- Create dummy data in db
	local set = chartfilesRepo:insertChartfileSet({
		name = "set",
		modified_at = 0,
		is_file = false,
		location_id = 1
	})
	
	local chartfile = chartfilesRepo:insertChartfile({
		name = "chart.sph",
		modified_at = 0,
		set_id = set.id
	})

	local function getCharts(_, path, content, hash)
		local ChartFormat = require("sea.chart.ChartFormat")
		local Chartmeta = require("sea.chart.Chartmeta")
		local meta = {
			hash = hash, 
			index = 1,
			inputmode = "4key",
			format = "sphere",
			title = "test",
			artist = "test",
			name = "test",
			created_at = 0,
			computed_at = 0
		}
		setmetatable(meta, Chartmeta)
		return {{
			chart = {inputMode = "4key"}, 
			chartmeta = meta
		}}
	end

	local cg = ChartmetaGenerator(chartsRepo, chartfilesRepo, {getCharts = getCharts})

	local content = "content"
	local expected_hash = digest.hash("md5", content, true)

	-- 1. Test initial caching
	local status, metas = cg:generate(chartfile, content)
	t:eq(status, "cached")
	t:eq(#metas, 1)
	
	-- Verify chartfile updated in DB
	local updated_cf = chartfilesRepo:selectChartfileById(chartfile.id)
	t:eq(updated_cf.hash, expected_hash)
	
	-- Verify chartmeta created in DB
	local meta = chartsRepo:getChartmetaByHashIndex(expected_hash, 1)
	t:assert(meta)
	t:eq(meta.title, "test")

	-- 2. Test reuse
	chartfile.hash = nil
	status, metas = cg:generate(chartfile, content)
	t:eq(status, "reused")
	t:eq(metas, nil)
	
	updated_cf = chartfilesRepo:selectChartfileById(chartfile.id)
	t:eq(updated_cf.hash, expected_hash)

	db:unload()
end

return test
