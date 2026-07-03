local Locations = require("rizu.library.Locations")
local LocationsRepo = require("rizu.library.repos.LocationsRepo")
local ChartfilesRepo = require("rizu.library.repos.ChartfilesRepo")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")

local test = {}

local function setup_db()
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	return db
end

function test.mounting(t)
	local db = setup_db()
	local locationsRepo = LocationsRepo(db.models)
	local chartfilesRepo = ChartfilesRepo(db.models)

	---@type {[string]: string}
	local mounts = {}
	local fs = {
		mount = function(_, src, mp)
			mounts[mp] = src
			return true
		end,
		unmount = function(_, src)
			for mp, arch in pairs(mounts) do
				if arch == src then
					mounts[mp] = nil
					return true
				end
			end
			return false
		end,
	}

	local lm = Locations(locationsRepo, chartfilesRepo, fs, "/game", "prefix")

	-- Test default location creation
	lm:load()
	local locations = locationsRepo:selectLocations()
	t:eq(#locations, 1)
	t:eq(locations[1].path, "userdata/charts")
	t:eq(locations[1].is_relative, true)

	-- Test adding a new external location
	---@type rizu.library.LocationInsert
	local loc2 = {
		path = "/ext/charts",
		name = "ext",
		is_relative = false,
		is_internal = false,
	}
	loc2 = locationsRepo:insertLocation(loc2)

	lm:selectLocations()
	lm:mountLocation(loc2)

	t:eq(mounts["prefix/" .. loc2.id], "/ext/charts")
	t:eq(lm:getPrefix(loc2), "prefix/" .. loc2.id)

	-- Test relative path conversion
	lm:updateLocationPath(loc2, "/game/my_charts")

	local updated_loc2 = locationsRepo:selectLocationById(loc2.id)
	---@cast updated_loc2 -?
	t:eq(updated_loc2.path, "my_charts")
	t:eq(updated_loc2.is_relative, true)
	t:eq(lm:getPrefix(updated_loc2), "my_charts")

	db:unload()
end

return test
