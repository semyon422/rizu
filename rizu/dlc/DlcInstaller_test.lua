local DlcInstaller = require("rizu.dlc.DlcInstaller")

local test = {}

---@class rizu.dlc.FakeDlcInstallFilesystem: rizu.dlc.IDlcInstallFilesystem
---@field dirs {[string]: true}
---@field files {[string]: string}

---@class rizu.dlc.FakeDlcExtractor: rizu.dlc.IDlcExtractor
---@field calls {archive: string, path: string}[]

---@return rizu.dlc.FakeDlcInstallFilesystem
local function new_fs()
	---@type {[string]: true}
	local dirs = {}
	---@type {[string]: string}
	local files = {}
	return {
		dirs = dirs,
		files = files,
		getInfo = function(path)
			return dirs[path] and {type = "directory"} or nil
		end,
		createDirectory = function(path)
			dirs[path] = true
			return true
		end,
		write = function(path, data)
			files[path] = data
			return true
		end,
	}
end

---@return rizu.dlc.FakeDlcExtractor
local function new_extractor()
	---@type {archive: string, path: string}[]
	local calls = {}
	return {
		calls = calls,
		extract = function(archive_path, extract_path)
			table.insert(calls, {archive = archive_path, path = extract_path})
			return true
		end,
	}
end

---@param t testing.T
function test.installs_osz_set_to_downloads(t)
	local fs = new_fs()
	local extractor = new_extractor()
	local installer = DlcInstaller(fs --[[@as any]], extractor)

	local ok, err = installer:install(123, "set", "data", "song.osz")

	t:eq(err, nil)
	t:eq(ok, true)
	t:eq(fs.dirs["userdata/charts/downloads"], true)
	t:eq(fs.files["userdata/charts/downloads/song.osz"], "data")
	t:tdeq(extractor.calls[1], {
		archive = "userdata/charts/downloads/song.osz",
		path = "userdata/charts/downloads/song",
	})
end

---@param t testing.T
function test.installs_zip_pack_to_packs(t)
	local fs = new_fs()
	local extractor = new_extractor()
	local installer = DlcInstaller(fs --[[@as any]], extractor)

	local ok, err = installer:install("pack", "pack", "zipdata", "pack.zip")

	t:eq(err, nil)
	t:eq(ok, true)
	t:eq(fs.dirs["userdata/charts/packs"], true)
	t:eq(fs.files["userdata/charts/packs/pack.zip"], "zipdata")
	t:tdeq(extractor.calls[1], {
		archive = "userdata/charts/packs/pack.zip",
		path = "userdata/charts/packs/pack",
	})
end

---@param t testing.T
function test.installs_file_to_metadata_destination(t)
	local fs = new_fs()
	local extractor = new_extractor()
	local installer = DlcInstaller(fs --[[@as any]], extractor)

	local ok, err = installer:install("file", "file", "chart", "chart.osu", {
		dest_dir = "userdata/charts/downloads/Artist - Song",
	})

	t:eq(err, nil)
	t:eq(ok, true)
	t:eq(fs.dirs["userdata/charts/downloads/Artist - Song"], true)
	t:eq(fs.files["userdata/charts/downloads/Artist - Song/chart.osu"], "chart")
	t:eq(extractor.calls[1], nil)
end

---@param t testing.T
function test.reports_extraction_error(t)
	local fs = new_fs()
	local extractor = {
		extract = function()
			return nil, "boom"
		end,
	}
	local installer = DlcInstaller(fs --[[@as any]], extractor)

	local ok, err = installer:install(123, "set", "data", "song.osz")

	t:eq(ok, nil)
	t:eq(err, "Extraction failed: boom")
end

return test
