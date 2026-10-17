local RemoteChartFiles = require("rizu.library.RemoteChartFiles")
local RemoteAssetCache = require("rizu.library.RemoteAssetCache")
local FakeFilesystem = require("fs.FakeFilesystem")
local digest = require("digest")

local test = {}

local chart = "osu file format v14"

---@param overrides table?
---@return rizu.library.LocatedChartview
local function newChartview(overrides)
	local chartview = {
		location_url = "https://cdn.test",
		hash = digest.hash("md5", chart, true),
		index = 1,
		path = "pack/Song/Song [Hard].osu",
		location_dir = "online/pack/Song",
		location_path = "online/pack/Song/Song [Hard].osu",
		audio_path = "audio.mp3",
		background_path = "bg.jpg",
	}
	for k, v in pairs(overrides or {}) do
		chartview[k] = v
	end
	return chartview
end

---@param bodies {[string]: string}
---@return rizu.library.RemoteChartFiles
---@return fs.FakeFilesystem
---@return string[] requested
local function newFiles(bodies)
	local fs = FakeFilesystem()
	local requested = {}
	local network = {
		download = function(_, url)
			table.insert(requested, url)
			local body = bodies[url]
			return {status = body and 200 or 404, body = body or ""}
		end,
	}
	local library = {
		getRemoteAssets = function(_, chartview)
			return chartview.location_url and {
				chart_url = "https://cdn.test/chart",
				audio_url = "https://cdn.test/audio",
				audio_preview_url = "https://cdn.test/preview",
				background_url = "https://cdn.test/bg",
			}
		end,
	}
	return RemoteChartFiles(library, RemoteAssetCache(network, fs, "cache"), fs), fs, requested
end

---@param t testing.T
function test.puts_the_files_where_the_chart_expects_them(t)
	local files, fs, requested = newFiles({
		["https://cdn.test/chart"] = chart,
		["https://cdn.test/audio"] = "opus",
		["https://cdn.test/bg"] = "avif",
	})
	local chartview = newChartview()

	t:tdeq({files:ensure(chartview)}, {true})
	t:eq(fs:read("online/pack/Song/Song [Hard].osu"), chart)
	t:eq(fs:read("online/pack/Song/audio.mp3"), "opus")
	t:eq(fs:read("online/pack/Song/bg.jpg"), "avif")

	-- Nothing is downloaded twice.
	t:tdeq({files:ensure(chartview)}, {true})
	t:eq(#requested, 3)
end

---@param t testing.T
function test.local_charts_need_nothing(t)
	local files, _, requested = newFiles({})
	t:tdeq({files:ensure(newChartview({location_url = false}))}, {true})
	t:eq(#requested, 0)
end

---@param t testing.T
function test.refuses_a_damaged_chart_and_unsafe_names(t)
	local files, fs = newFiles({
		["https://cdn.test/chart"] = "something else",
		["https://cdn.test/audio"] = "opus",
	})
	local ok, err = files:ensure(newChartview())
	t:eq(ok, nil)
	t:eq(err, "chart: the downloaded file is damaged")
	t:eq(fs:getInfo("online/pack/Song/Song [Hard].osu"), nil)

	ok, err = files:ensure(newChartview({path = "../Song.osu"}))
	t:eq(ok, nil)
	t:assert(err:find("unsupported file name", 1, true))
end

---@param t testing.T
function test.a_missing_background_is_not_an_error(t)
	local files = newFiles({
		["https://cdn.test/chart"] = chart,
		["https://cdn.test/audio"] = "opus",
	})
	t:tdeq({files:ensure(newChartview())}, {true})
end

return test
