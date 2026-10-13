local RemoteCatalogLoader = require("rizu.library.RemoteCatalogLoader")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local zlib = require("zlib")

local test = {}
local test_path = "userdata/remote_catalog_loader_test.sqlite"

---A catalog the way `CatalogBuilder` writes it: a library database with `catalog` added.
---@param schema_version integer
---@param charts string[] Hashes.
local function createCatalog(schema_version, charts)
	os.remove(test_path)
	local db = Database(LinuxFilesystem())
	db:load(test_path)
	db.db:exec(([[
		PRAGMA journal_mode = DELETE;
		CREATE TABLE catalog (schema_version INTEGER NOT NULL, version TEXT NOT NULL, generated_at INTEGER NOT NULL);
		INSERT INTO catalog VALUES (%d, 'v', 0);
		DELETE FROM locations;
		INSERT INTO locations VALUES (7, 'charts/pack', 'pack', 1, 0, NULL);
		INSERT INTO chartfile_sets VALUES (3, NULL, 'Song', 5, 0, 7);
	]]):format(schema_version))
	for i, hash in ipairs(charts) do
		db.db:exec(([[
			INSERT INTO chartfiles VALUES (%d, '%s.osu', '%s', 3, 5, 100);
			INSERT INTO chartmetas (created_at, computed_at, hash, `index`, inputmode, format, title)
				VALUES (0, 0, '%s', 1, '4key', 1, 'Catalog title');
			INSERT INTO chartdiffs (created_at, computed_at, hash, `index`, modifiers, rate, mode, inputmode, duration,
				start_time, notes_count, judges_count, note_types_count, density_data, sv_data, enps_diff, osu_diff,
				msd_diff, msd_diff_data, msd_diff_rates, user_diff, user_diff_data, notes_preview)
				VALUES (0, 0, '%s', 1, '', 1000, 0, '4key', 90, 0, 100, 100, '', '', '', 5, 2, 10, '', '', 0, '', '');
			INSERT INTO remote_assets VALUES ('%s', 1, 'chart-files/v1/%s.osu', 'audio/v1/a.webm', 'audio-previews/v1/p.webm', NULL);
		]]):format(40 + i, hash, hash, hash, hash, hash, hash))
	end
	db:unload()
end

---@return rizu.library.Database
local function createLibrary()
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	return db
end

---@param db rizu.library.Database
---@param sql string
---@return any
local function one(db, sql)
	local _, value = next(db.db:query(sql)[1])
	return value
end

---@param t testing.T
function test.decompresses_gzip_response(t)
	local body = "SQLite catalog bytes"
	t:eq(RemoteCatalogLoader.decodeBody("gzip", zlib.gzip(body)), body)
	t:eq(RemoteCatalogLoader.decodeBody(nil, body), body)
end

---@param t testing.T
function test.assets_are_relative_to_the_catalog(t)
	local loader = RemoteCatalogLoader({}, {}, "https://example.test/library/catalog.sqlite")
	t:eq(loader:getBaseUrl(), "https://example.test/library")
end

---@param t testing.T
function test.imports_the_catalog_as_a_remote_location(t)
	createCatalog(RemoteCatalogLoader.schema_version, {"a"})
	local db = createLibrary()
	-- The library already knows this chart; its own chartmeta is kept.
	db.db:exec([[
		INSERT INTO chartmetas (created_at, computed_at, hash, `index`, inputmode, format, title)
			VALUES (0, 0, 'a', 1, '4key', 1, 'Local title');
	]])

	local location_id, err = RemoteCatalogLoader.import(db.db, test_path, "https://cdn.test")
	t:eq(err, nil)
	t:eq(one(db, "SELECT url FROM locations WHERE id = " .. location_id), "https://cdn.test")
	t:eq(one(db, "SELECT path FROM locations WHERE id = " .. location_id), RemoteCatalogLoader.location_path)
	t:eq(one(db, "SELECT dir FROM chartfile_sets WHERE location_id = " .. location_id), "pack")
	t:eq(one(db, "SELECT hash FROM chartfiles"), "a")
	t:eq(one(db, "SELECT title FROM chartmetas"), "Local title")
	t:eq(tonumber(one(db, "SELECT COUNT(*) FROM chartdiffs")), 1)
	t:eq(one(db, "SELECT chart_path FROM remote_assets"), "chart-files/v1/a.osu")
	local chartfile_id = tonumber(one(db, "SELECT id FROM chartfiles"))

	-- A newer catalog adds its charts; what was imported keeps its ids and is not duplicated.
	createCatalog(RemoteCatalogLoader.schema_version, {"a", "b"})
	t:eq(RemoteCatalogLoader.import(db.db, test_path, "https://cdn.test"), location_id)
	t:eq(tonumber(one(db, "SELECT COUNT(*) FROM locations WHERE url IS NOT NULL")), 1)
	t:eq(tonumber(one(db, "SELECT COUNT(*) FROM chartfile_sets WHERE location_id = " .. location_id)), 1)
	t:eq(tonumber(one(db, "SELECT COUNT(*) FROM chartfiles")), 2)
	t:eq(tonumber(one(db, "SELECT id FROM chartfiles WHERE hash = 'a'")), chartfile_id)
	t:eq(tonumber(one(db, "SELECT COUNT(*) FROM chartmetas")), 2)
	t:eq(tonumber(one(db, "SELECT COUNT(*) FROM chartdiffs")), 2)
	t:eq(tonumber(one(db, "SELECT COUNT(*) FROM remote_assets")), 2)

	db:unload()
	os.remove(test_path)
end

---@param t testing.T
function test.sync_downloads_once_a_day(t)
	createCatalog(RemoteCatalogLoader.schema_version, {"a"})
	local body = assert(LinuxFilesystem():read(test_path))
	os.remove(test_path)

	local LibraryTestContext = require("rizu.library.LibraryTestContext")
	local ctx = LibraryTestContext()
	local downloads = 0
	local loader = RemoteCatalogLoader({
		download = function()
			downloads = downloads + 1
			return {status = 200, body = body, headers = {get = function() end}}
		end,
	}, LinuxFilesystem(), "https://cdn.test/catalog.sqlite", test_path)

	local location_id, err = loader:sync(ctx.lib)
	t:eq(err, nil)
	t:eq(ctx.lib.locations.locationsById[location_id].url, "https://cdn.test")
	t:eq(ctx.lib.chartfilesRepo:countChartfiles({hash = "a"}), 1)
	t:eq(loader:sync(ctx.lib), location_id)
	t:eq(downloads, 1)

	ctx:cleanup()
	os.remove(test_path)
end

---@param t testing.T
function test.rejects_incompatible_schema(t)
	createCatalog(10, {"a"})
	local db = createLibrary()
	local location_id, err = RemoteCatalogLoader.import(db.db, test_path, "https://cdn.test")
	t:eq(location_id, nil)
	t:assert(err:find("incompatible catalog schema 10", 1, true))
	t:eq(tonumber(one(db, "SELECT COUNT(*) FROM locations WHERE url IS NOT NULL")), 0)
	-- The library is usable afterwards.
	t:eq(tonumber(one(db, "SELECT COUNT(*) FROM chartfiles")), 0)

	db:unload()
	os.remove(test_path)
end

return test
