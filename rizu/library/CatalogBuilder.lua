local class = require("class")
local sqlite = require("ljsqlite3")
local zlib = require("zlib")
local path_util = require("path_util")
local Database = require("rizu.library.Database")
local Processor = require("rizu.library.Processor")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local FunctionTimer = require("time.FunctionTimer")

---One chart of the catalog and the files that belong to it.
---@class rizu.library.CatalogBuilder.Entry
---@field hash string
---@field index integer
---@field chartfile_id integer
---@field chart_source string
---@field audio_source string
---@field background_source string?
---@field preview_time number?
---@field duration number
---@field chart_path string? Relative to the catalog, filled in by the asset step.
---@field audio_path string?
---@field audio_preview_path string?
---@field background_path string?

---Builds the remote catalog: the library of the charts directory, made by the engine itself, and the files the
---client downloads. Charts are processed the way the game processes them, so the catalog is a library database
---(`rizu/library/sql/database.sql`, `sea/storage/shared/db.sql`) of the mania charts, with `remote_assets` filled
---and the table `catalog` added. Everything it makes can be reused by the next run.
---
---Only mania charts are included: the other modes have no chartdiffs yet.
---@class rizu.library.CatalogBuilder
---@operator call: rizu.library.CatalogBuilder
---@field charts_dir string
---@field out_dir string
---@field work_path string
---@field tools rizu.library.CatalogTools
---@field fs fs.IFilesystem
---@field log fun(message: string)
local CatalogBuilder = class()

-- Checked by the client against `catalog.schema_version`.
CatalogBuilder.schema_version = 12
CatalogBuilder.audio_profile = "opus-96k-stereo-v1"
CatalogBuilder.background_profile = "v2"
CatalogBuilder.chart_directory = "chart-files/v1"
CatalogBuilder.audio_directory = "audio/v1"
CatalogBuilder.audio_preview_directory = "audio-previews/v1"
CatalogBuilder.background_directory = "backgrounds/v2"

CatalogBuilder.catalog_sql = [[
CREATE TABLE catalog (
	`schema_version` INTEGER NOT NULL,
	`version` TEXT NOT NULL,
	`generated_at` INTEGER NOT NULL
);
]]

---@param options {charts_dir: string, out_dir: string, tools: rizu.library.CatalogTools, work_path: string?, fs: fs.IFilesystem?, log: (fun(message: string))?}
function CatalogBuilder:new(options)
	self.charts_dir = options.charts_dir
	self.out_dir = options.out_dir
	self.work_path = options.work_path or path_util.join(options.out_dir, "catalog-work.sqlite")
	self.tools = options.tools
	self.fs = options.fs or LinuxFilesystem()
	self.log = options.log or print
end

---The shortest text that reads back as the same number, which is how asset names have always been made.
---@param x number
---@return string
function CatalogBuilder.formatNumber(x)
	if x == math.floor(x) and math.abs(x) < 1e15 then
		return ("%d"):format(x)
	end
	for precision = 1, 17 do
		local s = ("%." .. precision .. "g"):format(x)
		if tonumber(s) == x then
			return s
		end
	end
	return tostring(x)
end

---@param conn table
---@param sql string
---@param ... any
---@return any[][]
local function query(conn, sql, ...)
	local statement = conn:prepare(sql)
	if select("#", ...) > 0 then
		statement:bind(...)
	end
	local rows = {}
	while true do
		local row = statement:step({})
		if not row then
			break
		end
		rows[#rows + 1] = row
	end
	statement:close()
	return rows
end

-- Library

---Lets the engine read, hash and measure every chart in the directory. A chart that is already known is skipped.
function CatalogBuilder:scan()
	assert(self.fs:createDirectory(self.out_dir))

	local db = Database(self.fs)
	db:load(self.work_path)
	local processor = Processor(function() end, db, self.fs, "/", FunctionTimer(os.clock))

	local names = {}
	for _, name in ipairs(self.fs:getDirectoryItems(self.charts_dir)) do
		local info = self.fs:getInfo(path_util.join(self.charts_dir, name))
		if info and (info.type == "directory" or info.type == "symlink") then
			names[#names + 1] = name
		end
	end
	table.sort(names)

	for _, name in ipairs(names) do
		local path = path_util.join(self.charts_dir, name)
		local location = processor.locationsRepo:selectLocation(path)
			or processor.locationsRepo:insertLocation({path = path, name = name, is_relative = true, is_internal = false})
		self.log("location " .. name)
		processor:computeLocation(nil, location.id)
	end
	self.log("difficulty")
	processor:computeChartdiffs()

	for _, err in ipairs(processor.errors) do
		self.log("error: " .. err)
	end
	db:unload()
end

---The mania charts of the library, one for each chart file.
---@return rizu.library.CatalogBuilder.Entry[]
function CatalogBuilder:getEntries()
	local conn = sqlite.open(self.work_path, "ro")
	local rows = query(conn, [[
		SELECT chartfiles.hash, chartmetas.`index`, MIN(chartfiles.id), chartfiles.name, chartfile_sets.dir,
			chartfile_sets.name, chartfile_sets.is_file, locations.path, chartmetas.audio_path,
			chartmetas.background_path, chartmetas.preview_time, chartdiffs.duration
		FROM chartfiles
		JOIN chartfile_sets ON chartfile_sets.id = chartfiles.set_id
		JOIN locations ON locations.id = chartfile_sets.location_id
		JOIN chartmetas ON chartmetas.hash = chartfiles.hash AND chartmetas.mode = 0
		JOIN chartdiffs ON chartdiffs.hash = chartmetas.hash AND chartdiffs.`index` = chartmetas.`index`
			AND chartdiffs.mode = 0 AND chartdiffs.rate = 1000 AND chartdiffs.modifiers = ''
		GROUP BY chartfiles.hash, chartmetas.`index`
		ORDER BY chartfiles.hash, chartmetas.`index`
	]])
	conn:close()

	---@type rizu.library.CatalogBuilder.Entry[]
	local entries = {}
	for _, row in ipairs(rows) do
		local directory = row[5]
		-- A folder holds its set, a single-file set is the file.
		if tonumber(row[7]) ~= 1 then
			directory = directory and path_util.join(directory, row[6]) or row[6]
		end
		local set_path = directory and path_util.join(row[8], directory) or row[8]
		local audio = row[9]
		local background = row[10]
		entries[#entries + 1] = {
			hash = row[1],
			index = tonumber(row[2]),
			chartfile_id = tonumber(row[3]),
			chart_source = path_util.join(set_path, row[4]),
			audio_source = audio and audio ~= "" and path_util.join(set_path, audio) or "",
			background_source = background and background ~= "" and path_util.join(set_path, background) or nil,
			preview_time = tonumber(row[11]),
			duration = tonumber(row[12]) or 0,
		}
	end
	return entries
end

-- Assets

---Makes the asset unless it is there. Names follow the content, so the same file is never made twice.
---@param relative_path string
---@param make fun(path: string): boolean?, string?
---@return boolean ok
---@return string? err
function CatalogBuilder:ensure(relative_path, make)
	local path = path_util.join(self.out_dir, relative_path)
	if self.fs:getInfo(path) then
		return true
	end
	assert(self.fs:createDirectory(path:match("^(.*)/[^/]+$")))
	return make(path)
end

---@param entry rizu.library.CatalogBuilder.Entry
---@return string? err
function CatalogBuilder:buildAssets(entry)
	local tools = self.tools
	local fs = self.fs

	if entry.audio_source == "" or not fs:getInfo(entry.audio_source) then
		return "no audio"
	end

	local extension = entry.chart_source:match("(%.[^./]+)$") or ""
	local chart_path = path_util.join(self.chart_directory, entry.hash .. extension:lower())
	local ok, err = self:ensure(chart_path, function(path)
		local data, read_err = fs:read(entry.chart_source)
		if not data then return nil, read_err end
		return fs:write(path, data)
	end)
	if not ok then return err end

	local audio_hash = tools:hashFile("sha256", entry.audio_source)
	local audio_path = path_util.join(self.audio_directory, ("%s-%s.webm"):format(audio_hash, self.audio_profile))
	ok, err = self:ensure(audio_path, function(path)
		return tools:encodeAudio(entry.audio_source, path)
	end)
	if not ok then return err end

	local preview_start = entry.preview_time and entry.preview_time > 0 and entry.preview_time or entry.duration * 0.4
	local preview_key = tools:hashString("sha256", table.concat({
		audio_hash, self.formatNumber(preview_start), self.audio_profile,
	}, "\0"))
	local audio_preview_path = path_util.join(self.audio_preview_directory, preview_key .. ".webm")
	ok, err = self:ensure(audio_preview_path, function(path)
		return tools:encodeAudio(entry.audio_source, path, preview_start)
	end)
	if not ok then return err end

	local background_path
	if entry.background_source and fs:getInfo(entry.background_source) then
		background_path = path_util.join(
			self.background_directory,
			tools:hashFile("md5", entry.background_source) .. ".avif"
		)
		ok, err = self:ensure(background_path, function(path)
			return tools:encodeBackground(entry.background_source, path)
		end)
		-- A chart without a background is still playable.
		if not ok then
			self.log("background: " .. tostring(err))
			background_path = nil
		end
	end

	entry.chart_path = chart_path
	entry.audio_path = audio_path
	entry.audio_preview_path = audio_preview_path
	entry.background_path = background_path
end

---@param entries rizu.library.CatalogBuilder.Entry[]
---@return rizu.library.CatalogBuilder.Entry[] built
function CatalogBuilder:buildAllAssets(entries)
	---@type rizu.library.CatalogBuilder.Entry[]
	local built = {}
	for i, entry in ipairs(entries) do
		local err = self:buildAssets(entry)
		if err then
			self.log(("skipped %s: %s"):format(entry.chart_source, err))
		else
			built[#built + 1] = entry
		end
		if i % 100 == 0 then
			self.log(("assets %d / %d"):format(i, #entries))
		end
	end
	return built
end

-- Catalog

---Writes `catalog.sqlite` and its gzip: the rows of these charts, copied from the library as they are.
---@param entries rizu.library.CatalogBuilder.Entry[]
---@param generated_at integer?
---@return string version
function CatalogBuilder:export(entries, generated_at)
	local temporary_path = path_util.join(self.out_dir, "catalog.sqlite.tmp")
	local path = path_util.join(self.out_dir, "catalog.sqlite")
	os.remove(temporary_path)

	-- The library creates its own tables, so the catalog cannot drift from them.
	local db = Database(self.fs)
	db:load(temporary_path)
	db:unload()

	local conn = sqlite.open(temporary_path)
	conn:exec("PRAGMA journal_mode = DELETE")
	conn:exec(("ATTACH '%s' AS work"):format((self.work_path:gsub("'", "''"))))
	conn:exec(self.catalog_sql)
	conn:exec("CREATE TEMP TABLE selection (`hash` TEXT, `index` INTEGER, chartfile_id INTEGER)")

	conn:exec("BEGIN")
	local insert_selection = conn:prepare("INSERT INTO selection VALUES (?, ?, ?)")
	local insert_asset = conn:prepare("INSERT INTO remote_assets VALUES (?, ?, ?, ?, ?, ?)")
	for _, entry in ipairs(entries) do
		insert_selection:reset():bind(entry.hash, entry.index, entry.chartfile_id):step()
		insert_asset:reset():bind(
			entry.hash, entry.index, entry.chart_path, entry.audio_path, entry.audio_preview_path, entry.background_path
		):step()
	end
	insert_selection:close()
	insert_asset:close()

	conn:exec([[
		INSERT INTO chartfile_sets SELECT * FROM work.chartfile_sets WHERE id IN (
			SELECT set_id FROM work.chartfiles WHERE id IN (SELECT chartfile_id FROM selection)
		);
		INSERT INTO chartfiles SELECT * FROM work.chartfiles WHERE id IN (SELECT chartfile_id FROM selection);
		INSERT INTO chartmetas SELECT m.* FROM work.chartmetas AS m
			JOIN selection ON selection.hash = m.hash AND selection.`index` = m.`index`;
		INSERT INTO chartdiffs SELECT d.* FROM work.chartdiffs AS d
			JOIN selection ON selection.hash = d.hash AND selection.`index` = d.`index`
			WHERE d.mode = 0 AND d.rate = 1000 AND d.modifiers = '';
		-- The files are relative to the catalog, wherever the library was built.
		INSERT INTO locations SELECT id, 'charts/' || name, name, 1, 0, NULL FROM work.locations WHERE id IN (
			SELECT location_id FROM chartfile_sets
		);
	]])
	conn:exec("COMMIT")

	local summary = {}
	for _, row in ipairs(query(conn, [[
		SELECT remote_assets.`hash`, remote_assets.`index`, remote_assets.audio_path, remote_assets.audio_preview_path,
			remote_assets.background_path, chartdiffs.msd_diff, chartdiffs.enps_diff, chartdiffs.osu_diff
		FROM remote_assets
		JOIN chartdiffs ON chartdiffs.`hash` = remote_assets.`hash` AND chartdiffs.`index` = remote_assets.`index`
		ORDER BY remote_assets.`hash`, remote_assets.`index`
	]])) do
		for i = 1, 8 do
			summary[#summary + 1] = tostring(row[i])
		end
	end
	local version = self.tools:hashString("sha256", table.concat(summary, "\0"))
	local insert_catalog = conn:prepare("INSERT INTO catalog VALUES (?, ?, ?)")
	insert_catalog:bind(self.schema_version, version, generated_at or os.time()):step()
	insert_catalog:close()

	conn:exec("DETACH work")
	conn:exec("VACUUM")
	conn:close()

	assert(os.rename(temporary_path, path))
	local data = assert(self.fs:read(path))
	assert(self.fs:write(path .. ".gz.tmp", zlib.gzip(data)))
	assert(os.rename(path .. ".gz.tmp", path .. ".gz"))
	return version
end

function CatalogBuilder:run()
	self:scan()
	local entries = self:getEntries()
	self.log(("%d mania charts"):format(#entries))
	local built = self:buildAllAssets(entries)
	local version = self:export(built)
	self.log(("catalog %s: %d charts, %d skipped"):format(version, #built, #entries - #built))
end

return CatalogBuilder
