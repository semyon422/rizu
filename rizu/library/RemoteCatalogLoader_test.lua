local RemoteCatalogLoader = require("rizu.library.RemoteCatalogLoader")
local sqlite = require("ljsqlite3")
local zlib = require("zlib")

local test = {}
local test_path = "userdata/remote_catalog_loader_test.sqlite"

local function createCatalog(version)
	os.remove(test_path)
	local db = sqlite.open(test_path)
	db:exec(([[
		PRAGMA user_version = %d;
		CREATE TABLE songs (id TEXT PRIMARY KEY, title TEXT NOT NULL, artist TEXT NOT NULL);
		CREATE TABLE charts (
			id TEXT PRIMARY KEY, song_id TEXT NOT NULL, name TEXT NOT NULL,
			creator TEXT NOT NULL, mode INTEGER NOT NULL, keys INTEGER,
			difficulty REAL NOT NULL, format TEXT NOT NULL, background_preview_path TEXT,
			audio_preview_path TEXT NOT NULL
		);
		INSERT INTO songs VALUES ('song', 'Title', 'Artist');
		INSERT INTO charts VALUES (
			'chart', 'song', 'Hard', 'Mapper', 3, 7, 12.5, 'osu',
			'backgrounds/bg.avif', 'audio-previews/preview.webm'
		);
	]]):format(version))
	db:close()
end

local function loader()
	return RemoteCatalogLoader({}, {}, "https://example.test/catalog.sqlite", test_path)
end

---@param t testing.T
function test.decompresses_gzip_response(t)
	local body = "SQLite catalog bytes"
	t:eq(RemoteCatalogLoader.decodeBody("gzip", zlib.gzip(body)), body)
	t:eq(RemoteCatalogLoader.decodeBody(nil, body), body)
end

---@param t testing.T
function test.loads_catalog_rows(t)
	createCatalog(RemoteCatalogLoader.schema_version)
	local items, err = loader():load()
	os.remove(test_path)

	t:eq(err, nil)
	t:eq(#items, 1)
	t:tdeq(items[1], {
		id = "chart",
		title = "Title",
		artist = "Artist",
		name = "Hard",
		creator = "Mapper",
		mode = 3,
		keys = 7,
		difficulty = 12.5,
		format = "osu",
		background_url = "https://example.test/backgrounds/bg.avif",
		preview_audio_url = "https://example.test/audio-previews/preview.webm",
	})
end

---@param t testing.T
function test.resolves_asset_urls_relative_to_catalog(t)
	t:eq(RemoteCatalogLoader.assetUrl(
		"https://example.test/library/catalog.sqlite",
		"backgrounds/bg.avif"
	), "https://example.test/library/backgrounds/bg.avif")
	t:eq(RemoteCatalogLoader.assetUrl("https://example.test/catalog.sqlite", nil), nil)
end

---@param t testing.T
function test.rejects_incompatible_schema(t)
	createCatalog(10)
	local items, err = loader():load()
	os.remove(test_path)

	t:eq(items, nil)
	t:assert(err:find("incompatible catalog schema 10", 1, true))
end

return test
