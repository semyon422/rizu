local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local OsuRepo = require("sea.osu.repos.OsuRepo")
local Chartmeta = require("sea.chart.Chartmeta")
local TestChartFactory = require("sea.chart.TestChartFactory")
local OsuBeatmap = require("sea.osu.OsuBeatmap")
local SeaBeatmapRepo = require("bancho.adapter.SeaBeatmapRepo")

local test = {}

local sample_osu = [[
osu file format v14

[General]
Mode: 3
AudioFilename: audio.mp3
PreviewTime: 0

[Metadata]
Title:Hydrated Title
Artist:Hydrated Artist
Creator:Hydrated Mapper
Version:Hydrated Diff
BeatmapID:777
BeatmapSetID:888

[Difficulty]
CircleSize:4
OverallDifficulty:8

[TimingPoints]
0,500,4,2,0,70,1,0

[HitObjects]
64,192,0,1,0,0:0:0:0:
192,192,1000,1,0,0:0:0:0:
320,192,2000,1,0,0:0:0:0:
448,192,3000,1,0,0:0:0:0:
]]

local function create_ctx(osu_beatmaps, charts_storage, fetch_osu_file)
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:remove()
	db:open()

	local charts_repo = ChartsRepo(db.models)
	local osu_repo = OsuRepo(db.models)
	local repo = SeaBeatmapRepo(charts_repo, osu_repo, osu_beatmaps, charts_storage, fetch_osu_file)

	return {
		db = db,
		charts_repo = charts_repo,
		osu_repo = osu_repo,
		repo = repo,
	}
end

---@param t testing.T
function test.find_beatmap_by_hash_uses_chartmeta_and_osu_data(t)
	local ctx = create_ctx()

	local chartmeta = Chartmeta()
	chartmeta.hash = "0123456789abcdef0123456789abcdef"
	chartmeta.index = 1
	chartmeta.inputmode = "4key"
	chartmeta.format = "osu"
	chartmeta.title = "Title"
	chartmeta.artist = "Artist"
	chartmeta.name = "Diff"
	chartmeta.creator = "Mapper"
	chartmeta.level = 5.5
	chartmeta.tempo = 180
	chartmeta.osu_beatmap_id = 123
	chartmeta.osu_beatmapset_id = 456
	chartmeta.osu_ranked_status = 4 -- deprecated/unused compatibility field
	chartmeta.created_at = 1
	chartmeta.computed_at = 2
	ctx.charts_repo:createChartmeta(chartmeta)

	local chartdiff = TestChartFactory():createChartdiff({
		hash = chartmeta.hash,
		index = 1,
		modifiers = {},
		rate = 1,
		mode = "mania",
		inputmode = "4key",
		duration = 123.9,
		notes_count = 999,
		judges_count = 999,
		osu_diff = 7.25,
		created_at = 1,
		computed_at = 2,
	})
	ctx.charts_repo:createChartdiff(chartdiff)

	local osu_beatmap = OsuBeatmap()
	osu_beatmap.id = 123
	osu_beatmap.beatmapset_id = 456
	osu_beatmap.hash = chartmeta.hash
	osu_beatmap.status = "ranked"
	osu_beatmap.updated_at = 10
	ctx.osu_repo:createBeatmap(osu_beatmap)

	local bmap = assert(ctx.repo:findBeatmap(chartmeta.hash))
	ctx.db:close()

	t:eq(bmap.id, 123)
	t:eq(bmap.set_id, 456)
	t:eq(bmap.md5, chartmeta.hash)
	t:eq(bmap.artist, "Artist")
	t:eq(bmap.title, "Title")
	t:eq(bmap.version, "Diff")
	t:eq(bmap.creator, "Mapper")
	t:eq(bmap.status, 2)
	t:eq(bmap.mode, 3)
	t:eq(bmap.bpm, 180)
	t:eq(bmap.total_length, 123)
	t:eq(bmap.max_combo, 999)
	t:eq(bmap.diff, 7.25)
	t:eq(bmap.last_update, 10)
	t:eq(bmap.full_name, "Artist - Title [Diff]")
end

---@param t testing.T
function test.find_beatmap_by_id_with_stubs(t)
	local ctx = create_ctx()

	local osu_beatmap = OsuBeatmap()
	osu_beatmap.id = 321
	osu_beatmap.beatmapset_id = 654
	osu_beatmap.hash = "fedcba9876543210fedcba9876543210"
	osu_beatmap.status = "ranked"
	osu_beatmap.updated_at = 20
	ctx.osu_repo:createBeatmap(osu_beatmap)

	local chartdiff = TestChartFactory():createChartdiff({
		hash = osu_beatmap.hash,
		index = 1,
		modifiers = {},
		rate = 1,
		mode = "mania",
		inputmode = "4key",
		duration = 88.2,
		notes_count = 321,
		judges_count = 321,
		osu_diff = 4.5,
		created_at = 1,
		computed_at = 2,
	})
	ctx.charts_repo:createChartdiff(chartdiff)

	local bmap = assert(ctx.repo:findBeatmapById(321))
	ctx.db:close()

	t:eq(bmap.id, 321)
	t:eq(bmap.set_id, 654)
	t:eq(bmap.md5, "fedcba9876543210fedcba9876543210")
	t:eq(bmap.artist, "")
	t:eq(bmap.title, "")
	t:eq(bmap.status, 2)
	t:eq(bmap.mode, 3)
	t:eq(bmap.total_length, 88)
	t:eq(bmap.max_combo, 321)
	t:eq(bmap.diff, 4.5)
	t:eq(bmap.full_name, "")
end

---@param t testing.T
function test.find_beatmap_hydrates_from_api_and_osu_file(t)
	local storage = {
		data = {},
		get = function(self, key)
			return self.data[key]
		end,
		set = function(self, key, value)
			self.data[key] = value
			return true
		end,
	}

	local osu_beatmaps = {
		getOrCreateOsuBeatmapByHash = function(self, hash, time)
			local beatmap = OsuBeatmap()
			beatmap.id = 777
			beatmap.beatmapset_id = 888
			beatmap.hash = hash
			beatmap.status = "ranked"
			beatmap.updated_at = time
			return beatmap
		end,
	}

	local ctx = create_ctx(osu_beatmaps, storage, function(_, beatmap_id)
		return sample_osu
	end)

	local md5 = require("digest").hash("md5", sample_osu, true)
	local bmap = assert(ctx.repo:findBeatmap(md5))
	local chartmeta = assert(ctx.charts_repo.models.chartmetas:find({hash = md5}))
	local chartdiff = assert(ctx.charts_repo:selectDefaultChartdiff(md5, 1))
	ctx.db:close()

	t:eq(storage.data[md5], sample_osu)
	t:eq(bmap.id, 777)
	t:eq(bmap.set_id, 888)
	t:eq(bmap.artist, "Hydrated Artist")
	t:eq(bmap.title, "Hydrated Title")
	t:eq(bmap.version, "Hydrated Diff")
	t:eq(chartmeta.osu_beatmap_id, 777)
	t:eq(chartmeta.osu_beatmapset_id, 888)
	t:eq(chartdiff.notes_count, 4)
end

---@param t testing.T
function test.find_beatmap_cached_missing_returns_nil_without_fetch(t)
	local fetch_calls = 0
	local ctx = create_ctx(nil, {
		get = function()
			return nil
		end,
		set = function()
			return true
		end,
	}, function()
		fetch_calls = fetch_calls + 1
		return nil, "must not fetch"
	end)

	local osu_beatmap = OsuBeatmap()
	osu_beatmap.hash = "00000000000000000000000000000000"
	osu_beatmap.status = "missing"
	osu_beatmap.updated_at = 20
	ctx.osu_repo:createBeatmap(osu_beatmap)

	t:eq(ctx.repo:findBeatmap(osu_beatmap.hash), nil)
	t:eq(fetch_calls, 0)
	ctx.db:close()
end

---@param t testing.T
function test.find_beatmap_missing_returns_nil(t)
	local ctx = create_ctx()
	t:eq(ctx.repo:findBeatmap("11111111111111111111111111111111"), nil)
	t:eq(ctx.repo:findBeatmapById(999), nil)
	ctx.db:close()
end

return test
