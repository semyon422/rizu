--- Tests for the beatmap loader.

local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

function test.load_local_osu_file(t)
	local BeatmapLoader = require("bancho.beatmap.BeatmapLoader")

	-- Create a fake filesystem with a sample .osu file
	local fs = FakeFilesystem()
	fs:createDirectory("storages/charts")
	fs:write("storages/charts/169f143ffb944145fafc9250371162c9", [[
osu file format v14

[General]
Mode: 3

[Metadata]
Title:Mr.RENDA
Artist:LuzeriA
Creator:Krimpus
Version:Insane
BeatmapID:4679273
BeatmapSetID:1234567

[Difficulty]
CircleSize:7.4
OverallDifficulty:7.4
ApproachRate:8.0
HPDrainRate:7.0

[TimingPoints]
0,270,4

[HitObjects]
0,0,100,129,0
128,0,170,129,0
256,0,240,129,0
384,0,310,129,0
512,0,380,129,0
]])

	local loader = BeatmapLoader(fs)
	local bmap, err = loader:load("169f143ffb944145fafc9250371162c9")
	t:ne(bmap, nil, "should load beatmap")
	t:eq(err, nil, "should not error")

	if bmap then
		t:eq(bmap.id, 4679273)
		t:eq(bmap.artist, "LuzeriA")
		t:eq(bmap.title, "Mr.RENDA")
		t:eq(bmap.creator, "Krimpus")
		t:eq(bmap.version, "Insane")
		t:eq(bmap.mode, 3) -- mania
		t:ne(bmap.diff, 0, "should have non-zero SR for mania")
		t:ne(bmap.od, 0, "should have OD")
	end
end

function test.parse_osu_content(t)
	local BeatmapLoader = require("bancho.beatmap.BeatmapLoader")
	local loader = BeatmapLoader()

	-- Minimal .osu content
	local content = [[
osu file format v14

[General]
AudioFilename: audio.mp3
Mode: 0

[Metadata]
Title:Test
TitleUnicode:Test
Artist:Artist
ArtistUnicode:Artist
Creator:Creator
Version:Easy
BeatmapID:12345
BeatmapSetID:67890

[Difficulty]
CircleSize:4
OverallDifficulty:5
ApproachRate:6
HPDrainRate:5

[TimingPoints]
0,500,4
]]

	local bmap, err = loader:parseOsu(content, "abc123")
	t:ne(bmap, nil, "should parse content")
	t:eq(err, nil, "should not error")

	if bmap then
		t:eq(bmap.id, 12345)
		t:eq(bmap.set_id, 67890)
		t:eq(bmap.md5, "abc123")
		t:eq(bmap.artist, "Artist")
		t:eq(bmap.title, "Test")
		t:eq(bmap.version, "Easy")
		t:eq(bmap.mode, 0)
		t:eq(bmap.cs, 4)
		t:eq(bmap.od, 5)
		t:eq(bmap.ar, 6)
		t:eq(bmap.hp, 5)
	end
end

function test.missing_beatmap_id(t)
	local BeatmapLoader = require("bancho.beatmap.BeatmapLoader")
	local loader = BeatmapLoader()

	local content = [[
osu file format v14

[General]
Mode: 0

[Metadata]
Title:Test
Artist:Artist
BeatmapID:0
BeatmapSetID:0

[Difficulty]
CircleSize:4
OverallDifficulty:5
ApproachRate:6
HPDrainRate:5

[TimingPoints]
0,500,4
]]

	local bmap, err = loader:parseOsu(content, "abc123")
	t:eq(bmap, nil, "should return nil for missing BeatmapID")
	t:ne(err, nil, "should return error")
end

function test.file_not_found(t)
	local BeatmapLoader = require("bancho.beatmap.BeatmapLoader")
	local fs = FakeFilesystem()
	local loader = BeatmapLoader(fs)

	local bmap, err = loader:load("nonexistent_md5_hash_12345")
	t:eq(bmap, nil, "should return nil for missing file")
	t:ne(err, nil, "should return error")
end

function test.calculate_bpm(t)
	local BeatmapLoader = require("bancho.beatmap.BeatmapLoader")
	local loader = BeatmapLoader()

	-- 60 BPM = 1000ms beat length
	local content = [[
osu file format v14

[General]
Mode: 3

[Metadata]
Title:Test
Artist:Artist
BeatmapID:1
BeatmapSetID:1

[Difficulty]
CircleSize:4
OverallDifficulty:5
ApproachRate:6
HPDrainRate:5

[TimingPoints]
0,1000,4

[HitObjects]
0,0,100,1,0
0,0,200,1,0
]]

	local bmap = loader:parseOsu(content, "abc123")
	t:eq(bmap.bpm, 60)
end

function test.mania_star_rating(t)
	local BeatmapLoader = require("bancho.beatmap.BeatmapLoader")
	local loader = BeatmapLoader()

	-- Mania map with some notes
	local content = [[
osu file format v14

[General]
Mode: 3

[Metadata]
Title:Test
Artist:Artist
BeatmapID:1
BeatmapSetID:1

[Difficulty]
CircleSize:4
OverallDifficulty:5
ApproachRate:6
HPDrainRate:5

[TimingPoints]
0,500,4

[HitObjects]
0,0,100,129,0
128,0,200,129,0
256,0,300,129,0
384,0,400,129,0
]]

	local bmap = loader:parseOsu(content, "abc123")
	t:ne(bmap.diff, 0, "mania should have non-zero SR")
	t:ne(bmap.diff, nil, "mania SR should be a number")
end

function test.osu_std_no_sr(t)
	local BeatmapLoader = require("bancho.beatmap.BeatmapLoader")
	local loader = BeatmapLoader()

	-- osu!std map - SR should be 0 (not implemented)
	local content = [[
osu file format v14

[General]
Mode: 0

[Metadata]
Title:Test
Artist:Artist
BeatmapID:1
BeatmapSetID:1

[Difficulty]
CircleSize:4
OverallDifficulty:5
ApproachRate:6
HPDrainRate:5

[TimingPoints]
0,500,4

[HitObjects]
100,100,100,1,0
200,200,200,1,0
]]

	local bmap = loader:parseOsu(content, "abc123")
	t:eq(bmap.diff, 0, "osu!std SR should be 0 (not implemented)")
end

function test.api_fallback(t)
	-- Read API key from prod config; skip if not configured
	local prod_config = require("bancho.config")
	if not prod_config.osu_api_key then
		return
	end

	local BeatmapLoader = require("bancho.beatmap.BeatmapLoader")

	-- Empty filesystem forces API fallback
	local loader = BeatmapLoader(FakeFilesystem(), prod_config.osu_api_key)

	-- Fetch a real beatmap from osu! API v1
	local bmap, err = loader:load("1cf5b2c2edfafd055536d2cefcb89c0e")
	t:ne(bmap, nil, "should load from API")
	t:eq(err, nil, "should not error")

	if bmap then
		t:eq(bmap.id, 315)
		t:eq(bmap.artist, "FAIRY FORE")
		t:eq(bmap.title, "Vivid")
		t:eq(bmap.version, "Insane")
		t:eq(bmap.mode, 0)
		t:ne(bmap.diff, 0, "API should return SR")
		t:ne(bmap.bpm, 0, "API should return BPM")
	end
end

function test.api_fallback_no_key(t)
	local BeatmapLoader = require("bancho.beatmap.BeatmapLoader")

	-- No API key configured
	local loader = BeatmapLoader(FakeFilesystem())

	local bmap, err = loader:load("1cf5b2c2edfafd055536d2cefcb89c0e")
	t:eq(bmap, nil, "should return nil")
	t:ne(err, nil, "should return error")
	t:ne(string.find(err, "osu_api_key"), nil, "error should mention missing key")
end

return test
