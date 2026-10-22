local ComputeDataProvider = require("rizu.library.ComputeDataProvider")
local ChartfilesRepo = require("rizu.library.repos.ChartfilesRepo")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local LocationsRepo = require("rizu.library.repos.LocationsRepo")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local digest = require("digest")
local FakeFilesystem = require("fs.FakeFilesystem")
local Fixtures = require("chart.format.iidx.TestFixtures")
local RemoteValidation = require("sea.compute.remotes.ComputeDataProviderRemoteValidation")

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

function test.getIidxMetadata(t)
	local db = setup_db()
	local files = ChartfilesRepo(db.models)
	local locationsRepo = LocationsRepo(db.models)
	local location = locationsRepo:insertLocation({
		path = "data", name = "IIDX", is_relative = true, is_internal = true,
	})
	local set = files:insertChartfileSet({
		name = "01234.ifs", dir = "sound", modified_at = 0, is_file = false, location_id = location.id,
	})
	local hash = digest.hash("md5", Fixtures.sampleChart(), true)
	files:insertChartfile({
		name = "01234/01234.1", hash = hash, set_id = set.id, modified_at = 0,
	})
	local fs = FakeFilesystem()
	fs:createDirectory("data/sound")
	fs:createDirectory("data/info/0")
	fs:write("data/info/0/music_data.bin", Fixtures.sampleMusicDb())
	local provider = RemoteValidation(ComputeDataProvider(files, ChartsRepo(db.models), locationsRepo, {
		getPrefix = function(_, loc) return loc.path end,
	}, fs))
	local metadata = assert(provider:getIidxMetadata(hash))
	t:eq(metadata.song_id, 1234)
	t:eq(metadata.title, "Fixture Song")
	t:eq(metadata.artist, "Fixture Artist")
	t:eq(metadata.genre, "Fixture Genre")
	t:eq(metadata.levels.SPN, 3)
	t:eq(metadata.levels.DPN, 4)
	t:eq(provider:getIidxMetadata(string.rep("0", 32)), nil)
	db:unload()
end

return test
