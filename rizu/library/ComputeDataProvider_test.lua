local ComputeDataProvider = require("rizu.library.ComputeDataProvider")
local ChartfilesRepo = require("rizu.library.repos.ChartfilesRepo")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local LocationsRepo = require("rizu.library.repos.LocationsRepo")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local digest = require("digest")

local test = {}

local function setup_db()
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	return db
end

function test.getChartData(t)
	local db = setup_db()
	local chartfilesRepo = ChartfilesRepo(db.models)
	local chartsRepo = ChartsRepo(db.models)
	local locationsRepo = LocationsRepo(db.models)

	local content = "content"
	local valid_hash = digest.hash("md5", content, true)

	---@type rizu.library.LocationInsert
	local loc = {
		path = "charts", name = "game", is_relative = true, is_internal = true,
	}
	loc = locationsRepo:insertLocation(loc)

	local set = chartfilesRepo:insertChartfileSet({
		name = "set", dir = "dir", modified_at = 0, is_file = false, location_id = loc.id,
	})

	chartfilesRepo:insertChartfile({
		name = "chart.sph", hash = valid_hash, set_id = set.id, path = "dir/set/chart.sph", modified_at = 0,
	})

	local locations = {
		getPrefix = function(_, l) return l.path end,
	}

	local fs = {
		read = function(_, path)
			if path == "charts/dir/set/chart.sph" then return content end
		end,
	}

	local cdp = ComputeDataProvider(chartfilesRepo, chartsRepo, locationsRepo, locations, fs)

	local data, err = cdp:getChartData(valid_hash)
	t:assert(data, err)
	---@cast data -?
	t:eq(data.name, "chart.sph")
	t:eq(data.data, content)

	db:unload()
end

return test
