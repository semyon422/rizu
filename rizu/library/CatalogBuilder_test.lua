local CatalogBuilder = require("rizu.library.CatalogBuilder")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local sqlite = require("ljsqlite3")

local test = {}

local directory = "userdata/catalog_builder_test"

local osu_mania = [[
osu file format v14

[General]
AudioFilename: audio.mp3
PreviewTime: 1500
Mode: 3

[Metadata]
Title:Song
Artist:Someone
Creator:Mapper
Version:Hard
BeatmapID:1
BeatmapSetID:1

[Events]
0,0,"bg.jpg",0,0

[Difficulty]
CircleSize:4
OverallDifficulty:8

[TimingPoints]
0,500,4,1,0,100,1,0

[HitObjects]
64,192,1000,1,0,0:0:0:0:
192,192,1500,1,0,0:0:0:0:
320,192,2000,128,0,3000:0:0:0:0:
448,192,2500,1,0,0:0:0:0:
]]

local osu_standard = osu_mania:gsub("Mode: 3", "Mode: 0"):gsub("Version:Hard", "Version:Std")

---@return rizu.library.CatalogTools
local function newTools(log)
	return {
		hashFile = function(_, algorithm, path) return algorithm .. ":" .. path:match("[^/]+$") end,
		hashString = function(_, algorithm, s) return algorithm .. ":" .. #s end,
		encodeAudio = function(_, source, output, start)
			table.insert(log, "audio " .. (start and "preview " or "") .. output:match("[^/]+$"))
			return LinuxFilesystem():write(output, "audio")
		end,
		encodeBackground = function(_, source, output)
			table.insert(log, "background " .. output:match("[^/]+$"))
			return LinuxFilesystem():write(output, "background")
		end,
	}
end

local function cleanup()
	os.execute("rm -rf " .. directory)
end

---@param t testing.T
function test.builds_a_library_database_of_mania_charts(t)
	cleanup()
	local fs = LinuxFilesystem()
	local set = directory .. "/charts/pack/1 Someone - Song"
	assert(fs:createDirectory(set))
	assert(fs:write(set .. "/Song [Hard].osu", osu_mania))
	assert(fs:write(set .. "/Song [Std].osu", osu_standard))
	assert(fs:write(set .. "/audio.mp3", "mp3"))
	assert(fs:write(set .. "/bg.jpg", "jpg"))
	local no_audio = directory .. "/charts/pack/2 Nobody - Silence"
	assert(fs:createDirectory(no_audio))
	assert(fs:write(no_audio .. "/Silence [Hard].osu", osu_mania:gsub("BeatmapID:1", "BeatmapID:2")))

	local log = {}
	local lines = {}
	local builder = CatalogBuilder({
		charts_dir = directory .. "/charts",
		out_dir = directory .. "/out",
		tools = newTools(log),
		log = function(line) table.insert(lines, line) end,
	})
	builder:run()

	local conn = sqlite.open(directory .. "/out/catalog.sqlite", "ro")
	local function one(sql) return conn:rowexec(sql) end
	t:eq(tonumber(one("SELECT schema_version FROM catalog")), CatalogBuilder.schema_version)
	-- Only the mania chart that has its audio.
	t:eq(tonumber(one("SELECT COUNT(*) FROM chartmetas")), 1)
	t:eq(tonumber(one("SELECT COUNT(*) FROM chartdiffs")), 1)
	t:eq(tonumber(one("SELECT COUNT(*) FROM chartfiles")), 1)
	t:eq(tonumber(one("SELECT COUNT(*) FROM chartfile_sets")), 1)
	t:eq(tonumber(one("SELECT notes_count FROM chartdiffs")), 4)
	t:assert(tonumber(one("SELECT enps_diff FROM chartdiffs")) ~= nil)
	t:eq(one("SELECT title FROM chartmetas"), "Song")
	t:eq(one("SELECT path FROM locations"), "charts/pack")
	local hash = one("SELECT hash FROM chartfiles")
	t:eq(one("SELECT chart_path FROM remote_assets"), "chart-files/v1/" .. hash .. ".osu")
	t:eq(one("SELECT audio_path FROM remote_assets"), "audio/v1/sha256:audio.mp3-opus-96k-stereo-v1.webm")
	t:eq(one("SELECT background_path FROM remote_assets"), "backgrounds/v2/md5:bg.jpg.avif")
	t:assert(one("SELECT audio_preview_path FROM remote_assets"):find("^audio%-previews/v1/sha256:%d+%.webm$"))
	conn:close()

	t:assert(fs:getInfo(directory .. "/out/catalog.sqlite.gz"))
	t:assert(fs:getInfo(directory .. "/out/chart-files/v1/" .. hash .. ".osu"))
	t:eq(#log, 3)

	-- A second run encodes nothing.
	log = {}
	builder.tools = newTools(log)
	builder:run()
	t:eq(#log, 0)

	cleanup()
end

---@param t testing.T
function test.formats_numbers_as_short_as_possible(t)
	t:eq(CatalogBuilder.formatNumber(142.253), "142.253")
	t:eq(CatalogBuilder.formatNumber(30), "30")
	t:eq(CatalogBuilder.formatNumber(0.1 + 0.2), "0.30000000000000004")
end

return test
