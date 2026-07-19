local FakeFilesystem = require("fs.FakeFilesystem")
local ChartExporter = require("rizu.library.ChartExporter")
local AudioEngine = require("rizu.engine.audio.Engine")
local Fixtures = require("chart.format.iidx.TestFixtures")
local Wave = require("audio.Wave")
local zip = require("zip")

local test = {}

local osu_data = [[osu file format v14

[General]
AudioFilename: audio.wav
Mode: 3

[Metadata]
Title:Test Song
Artist:Test Artist
Creator:Mapper
Version:Normal

[Difficulty]
CircleSize:4

[Events]

[TimingPoints]
0,500,4,1,0,100,1,0

[HitObjects]
64,192,1000,1,0,0:0:0:0:
]]

---@return fs.FakeFilesystem, rizu.library.Library
local function createLibrary()
	local fs = FakeFilesystem()
	fs:createDirectory("charts/set")
	fs:write("charts/set/chart.osu", osu_data)
	local wave = Wave()
	wave:initBuffer(2, 10)
	local audio = wave:encode()
	fs:write("charts/set/audio.wav", audio)

	local chartfile_set = {
		id = 1,
		location_id = 1,
		name = "Test Set",
		dir = "charts",
		is_file = false,
	}
	local library = {
		fs = fs,
		chartfilesRepo = {
			selectChartfileSetById = function()
				return chartfile_set
			end,
			selectChartfilesBySet = function()
				return {{id = 1, set_id = 1, name = "chart.osu", modified_at = 0}}
			end,
		},
		enrichChartview = function(_, chartfile)
			chartfile.location_prefix = "."
			chartfile.location_dir = "charts/set"
			chartfile.location_path = "charts/set/chart.osu"
		end,
	}
	return fs, library
end

---@param t testing.T
function test.exports_set_charts_and_audio_to_osz(t)
	local fs, library = createLibrary()
	local path = ChartExporter(library):exportToOsz({chartfile_set_id = 1}, false)
	t:eq(path, "userdata/export/Test Set.osz")

	local reader = zip.Reader(assert(fs:read(path)))
	local names = {}
	for _, entry in ipairs(reader.entries) do
		names[entry.name] = true
	end
	t:assert(names["audio.wav"])
	t:assert(names["Test Artist - Test Song (Mapper) [Normal].osu"])
	t:eq(reader:extract("audio.wav"), assert(fs:read("charts/set/audio.wav")))
end

---@param t testing.T
function test.compiles_chart_audio_to_one_wave(t)
	local fs, library = createLibrary()
	local exporter = ChartExporter(library)
	exporter.audio_engine_factory = function()
		return AudioEngine()
	end
	local path = exporter:exportToOsz({chartfile_set_id = 1}, true)
	t:eq(path, "userdata/export/Test Set-compiled.osz")

	local reader = zip.Reader(assert(fs:read(path)))
	local names = {}
	local osu_name
	for _, entry in ipairs(reader.entries) do
		names[entry.name] = true
		if entry.name:match("%.osu$") then
			osu_name = entry.name
		end
	end
	t:assert(names["audio-1.wav"])
	t:assert(osu_name)
	local exported_osu = reader:extract(osu_name)
	t:assert(exported_osu:find("AudioFilename: audio%-1%.wav"))
	t:assert(not names["audio.wav"])
end

---@return fs.FakeFilesystem, rizu.library.Library
local function createIidxLibrary()
	local fs = FakeFilesystem()
	fs:createDirectory("data/info/30")
	fs:createDirectory("data/sound")
	fs:write("data/info/30/music_data.bin", Fixtures.sampleMusicDb())
	fs:write("data/sound/01234.ifs", Fixtures.ifs(
		1234,
		Fixtures.sampleChart(),
		Fixtures.s3p({"RIFFsound1", "RIFFsound2", "RIFFsound3"})
	))

	local chartfile_set = {
		id = 1,
		location_id = 1,
		name = "01234.ifs",
		dir = "sound",
		is_file = false,
	}
	local library = {
		fs = fs,
		chartfilesRepo = {
			selectChartfileSetById = function()
				return chartfile_set
			end,
			selectChartfilesBySet = function()
				return {{id = 1, set_id = 1, name = "01234/01234.1", modified_at = 0, hash = string.rep("0", 32)}}
			end,
		},
		enrichChartview = function(_, chartfile)
			chartfile.location_prefix = "data"
			chartfile.location_dir = "data/sound/01234.ifs"
			chartfile.location_path = "data/sound/01234.ifs/01234/01234.1"
		end,
	}
	return fs, library
end

---@param t testing.T
function test.exports_iidx_s3p_keysounds_as_referenced_files(t)
	local fs, library = createIidxLibrary()
	local path = ChartExporter(library):exportToOsz({chartfile_set_id = 1}, false)
	t:eq(path, "userdata/export/01234.ifs.osz")

	local reader = zip.Reader(assert(fs:read(path)))
	local names = {}
	local osu_name
	for _, entry in ipairs(reader.entries) do
		names[entry.name] = true
		if entry.name:match("%.osu$") then
			osu_name = entry.name
		end
	end
	t:assert(not names["01234/01234.s3p"])
	t:assert(names["keysounds/1.wav"])
	t:assert(names["keysounds/2.wav"])
	t:assert(names["keysounds/3.wav"])
	t:eq(reader:extract("keysounds/1.wav"), "RIFFsound1")
	t:assert(osu_name)
	local exported_osu = reader:extract(osu_name)
	t:assert(exported_osu:find("keysounds/1%.wav", 1, false))
	t:assert(exported_osu:find("keysounds/3%.wav", 1, false))
end

return test
