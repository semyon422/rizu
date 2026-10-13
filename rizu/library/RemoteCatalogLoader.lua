local class = require("class")
local zlib = require("zlib")

---Brings the remote catalog into the library: downloads the catalog database and copies its charts into
---a remote location. From then on they are charts of the library whose files are downloaded when played.
---@class rizu.library.RemoteCatalogLoader
---@operator call: rizu.library.RemoteCatalogLoader
---@field network rizu.NetworkService
---@field fs fs.IFilesystem
---@field url string
---@field path string
local RemoteCatalogLoader = class()

-- `catalog.schema_version`, written by `rizu.library.CatalogBuilder`.
RemoteCatalogLoader.schema_version = 12
-- The charts of the catalog are downloaded here.
RemoteCatalogLoader.location_path = "userdata/online/charts"
RemoteCatalogLoader.location_name = "online"
-- The catalog is downloaded again when the one on disk is older than this, in seconds.
RemoteCatalogLoader.max_age = 24 * 60 * 60

---@param network rizu.NetworkService
---@param fs fs.IFilesystem
---@param url string?
---@param path string?
function RemoteCatalogLoader:new(network, fs, url, path)
	self.network = assert(network, "network is required")
	self.fs = assert(fs, "filesystem is required")
	self.url = url or "https://s3.kuudere.fun/catalog.sqlite"
	self.path = path or "userdata/online/catalog.sqlite"
end

---@param encoding string?
---@param body string
---@return string
function RemoteCatalogLoader.decodeBody(encoding, body)
	if encoding and encoding:lower():find("gzip", 1, true) then
		return zlib.gunzip(body)
	end
	return body
end

---The files of the catalog are relative to it.
---@return string
function RemoteCatalogLoader:getBaseUrl()
	return self.url:match("^(.*)/[^/]*$") or self.url
end

---Downloads the catalog database to `path`. Yields.
---@param on_status fun(status: table)?
---@return true?
---@return string?
function RemoteCatalogLoader:download(on_status)
	local res, err = self.network:download(self.url, {
		chunk_size = 64 * 1024,
		on_status = on_status,
	})
	if not res then
		return nil, err or "download failed"
	end
	if res.status >= 400 then
		return nil, "HTTP " .. res.status
	end

	local ok, body = pcall(self.decodeBody, res.headers:get("Content-Encoding"), res.body)
	if not ok then
		return nil, "could not decompress catalog: " .. tostring(body)
	end

	local directory = self.path:match("^(.*)/[^/]+$")
	if directory then
		local created, create_err = self.fs:createDirectory(directory)
		if not created then
			return nil, create_err or "could not create catalog directory"
		end
	end
	local written, write_err = self.fs:write(self.path, body)
	if not written then
		return nil, write_err or "could not write catalog"
	end
	return true
end

---The columns both databases have, without the id: rows get the ids of the library.
---@param db rdb.SqliteDatabase
---@param table_name string
---@return string
local function sharedColumns(db, table_name)
	local in_catalog = {} ---@type {[string]: true}
	for _, row in ipairs(db:query(("PRAGMA catalog.table_info(%s)"):format(table_name))) do
		in_catalog[row.name] = true
	end
	local columns = {} ---@type string[]
	for _, row in ipairs(db:query(("PRAGMA main.table_info(%s)"):format(table_name))) do
		if row.name ~= "id" and in_catalog[row.name] then
			columns[#columns + 1] = "`" .. row.name .. "`"
		end
	end
	return table.concat(columns, ", ")
end

-- The catalog's locations become the top folders of the one remote location.
local set_dir = "CASE WHEN s.dir IS NULL THEN l.name ELSE l.name || '/' || s.dir END"

---@param db rdb.SqliteDatabase
---@param schema_version integer
---@param base_url string
---@return integer location_id
local function copy(db, schema_version, base_url)
	local version = tonumber(db:query("SELECT schema_version FROM catalog.catalog")[1].schema_version)
	if version ~= schema_version then
		error(("incompatible catalog schema %s; expected %d"):format(tostring(version), schema_version), 0)
	end

	local location = db:query("SELECT id FROM locations WHERE url = ?", {base_url})[1]
	if not location then
		db:query("INSERT INTO locations (path, name, is_relative, is_internal, url) VALUES (?, ?, 1, 0, ?)", {
			RemoteCatalogLoader.location_path, RemoteCatalogLoader.location_name, base_url,
		})
		location = db:query("SELECT id FROM locations WHERE url = ?", {base_url})[1]
	end
	local location_id = tonumber(location.id) --[[@as integer]]

	-- shortcut: charts removed from the catalog stay listed, delete them here when the catalog starts dropping charts
	db:query(([[
		INSERT OR IGNORE INTO chartfile_sets (dir, name, modified_at, is_file, location_id)
		SELECT %s, s.name, s.modified_at, s.is_file, ?
		FROM catalog.chartfile_sets AS s
		JOIN catalog.locations AS l ON l.id = s.location_id
	]]):format(set_dir), {location_id})
	-- Known chart files keep their ids: the selection and the downloaded files refer to them.
	db:query(([[
		INSERT INTO chartfiles (name, hash, set_id, modified_at, size)
		SELECT f.name, f.hash, ns.id, f.modified_at, f.size
		FROM catalog.chartfiles AS f
		JOIN catalog.chartfile_sets AS s ON s.id = f.set_id
		JOIN catalog.locations AS l ON l.id = s.location_id
		JOIN chartfile_sets AS ns ON ns.location_id = ? AND ns.dir = %s AND ns.name = s.name
		WHERE true
		ON CONFLICT (set_id, name) DO UPDATE SET hash = excluded.hash, modified_at = excluded.modified_at,
			size = excluded.size
	]]):format(set_dir), {location_id})

	-- What the library has measured itself is kept.
	local chartmeta_columns = sharedColumns(db, "chartmetas")
	db:query(("INSERT OR IGNORE INTO chartmetas (%s) SELECT %s FROM catalog.chartmetas"):format(
		chartmeta_columns, chartmeta_columns
	))
	local chartdiff_columns = sharedColumns(db, "chartdiffs")
	db:query(([[
		INSERT INTO chartdiffs (%s) SELECT %s FROM catalog.chartdiffs AS c
		WHERE NOT EXISTS (
			SELECT 1 FROM chartdiffs AS d WHERE d.hash = c.hash AND d.`index` = c.`index`
				AND d.modifiers = c.modifiers AND d.rate = c.rate AND d.mode = c.mode
		)
	]]):format(chartdiff_columns, chartdiff_columns))

	db:query([[
		INSERT OR REPLACE INTO remote_assets (hash, `index`, chart_path, audio_path, audio_preview_path, background_path)
		SELECT hash, `index`, chart_path, audio_path, audio_preview_path, background_path FROM catalog.remote_assets
	]])

	return location_id
end

---Copies the charts of a downloaded catalog into the library, into the remote location of `base_url`.
---Importing a newer catalog adds its charts and keeps the rows that are already there.
---@param db rdb.SqliteDatabase The library database.
---@param path string The catalog database.
---@param base_url string
---@return integer? location_id
---@return string? err
function RemoteCatalogLoader.import(db, path, base_url)
	local attached, attach_err = pcall(db.query, db, "ATTACH ? AS catalog", {path})
	if not attached then
		return nil, tostring(attach_err)
	end
	db:query("BEGIN IMMEDIATE")
	local ok, result = pcall(copy, db, RemoteCatalogLoader.schema_version, base_url)
	db:query(ok and "COMMIT" or "ROLLBACK")
	db:query("DETACH catalog")
	if not ok then
		return nil, tostring(result)
	end
	return result
end

---Makes the charts of the catalog part of the library: downloads the catalog when there is none or it is
---old, and imports what was downloaded. Yields.
---@param library rizu.library.Library
---@return integer? location_id
---@return string? err
function RemoteCatalogLoader:sync(library)
	local base_url = self:getBaseUrl()
	local info = self.fs:getInfo(self.path)
	if info and os.time() - info.modtime < self.max_age then
		for _, location in ipairs(library.locations.locations) do
			if location.url == base_url then
				return location.id
			end
		end
	else
		local ok, err = self:download()
		-- An old catalog is better than none.
		if not ok and not info then
			return nil, err
		end
	end
	return library:importCatalogAsync(self.path, base_url)
end

return RemoteCatalogLoader
