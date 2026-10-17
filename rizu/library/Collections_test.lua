local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local ChartfilesRepo = require("rizu.library.repos.ChartfilesRepo")
local LocationsRepo = require("rizu.library.repos.LocationsRepo")
local Collections = require("rizu.library.Collections")

local test = {}

local function setup()
	local db = Database(LinuxFilesystem())
	db:load(":memory:")

	local chartfilesRepo = ChartfilesRepo(db.models)
	local locationsRepo = LocationsRepo(db.models)
	local collections = Collections(chartfilesRepo, locationsRepo)

	return db, collections
end

---@param t testing.T
function test.generate_flat(t)
	local db, collections = setup()

	db.models.locations:create({
		id = 1,
		name = "Test Location",
		path = "/test",
		is_relative = 0,
		is_internal = 0,
	})

	db.models.chartfile_sets:create({
		id = 1,
		location_id = 1,
		name = "Set 1",
		dir = "dir1/subdir1",
		modified_at = 0,
		is_file = 0,
	})

	db.models.chartfile_sets:create({
		id = 2,
		location_id = 1,
		name = "Set 2",
		dir = "dir1/subdir2",
		modified_at = 0,
		is_file = 0,
	})

	local tree = collections:getTree(false)

	t:eq(tree.name, "/")
	t:eq(tree.count, 2)
	t:assert(tree.indexes["dir1"], "dir1 should be in root")

	local dir1 = tree.items[tree.indexes["dir1"]]
	t:eq(dir1.name, "dir1")
	t:eq(dir1.count, 2)
	t:assert(dir1.indexes["subdir1"], "subdir1 should be in dir1")
	t:assert(dir1.indexes["subdir2"], "subdir2 should be in dir1")

	local subdir1 = dir1.items[dir1.indexes["subdir1"]]
	t:eq(subdir1.name, "subdir1")
	t:eq(subdir1.count, 1)

	db:unload()
end

---@param t testing.T
function test.generate_with_locations(t)
	local db, collections = setup()

	db.models.locations:create({
		id = 1,
		name = "Location 1",
		path = "/loc1",
		is_relative = 0,
		is_internal = 0,
	})

	db.models.locations:create({
		id = 2,
		name = "Location 2",
		path = "/loc2",
		is_relative = 0,
		is_internal = 0,
	})

	db.models.chartfile_sets:create({
		id = 1,
		location_id = 1,
		name = "Set 1",
		dir = "dir1",
		modified_at = 0,
		is_file = 0,
	})

	db.models.chartfile_sets:create({
		id = 2,
		location_id = 2,
		name = "Set 2",
		dir = "dir2",
		modified_at = 0,
		is_file = 0,
	})

	local tree = collections:getTree(true)

	t:eq(tree.name, "/")
	t:eq(#tree.items, 3) -- root itself + 2 locations

	local loc1 = tree.items[2]
	t:eq(loc1.name, "Location 1")
	t:eq(loc1.count, 1)
	t:assert(loc1.indexes["dir1"])

	local loc2 = tree.items[3]
	t:eq(loc2.name, "Location 2")
	t:eq(loc2.count, 1)
	t:assert(loc2.indexes["dir2"])

	db:unload()
end

return test
