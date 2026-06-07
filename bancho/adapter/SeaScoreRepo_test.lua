local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local SharedMemory = require("web.nginx.SharedMemory")
local FakeFilesystem = require("fs.FakeFilesystem")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local Repos = require("sea.app.Repos")
local Domain = require("sea.app.Domain")
local User = require("sea.access.User")
local Replay = require("sea.replays.Replay")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local SeaScoreRepo = require("bancho.adapter.SeaScoreRepo")
local SeaReplayRepo = require("bancho.adapter.SeaReplayRepo")
local SeaBeatmapRepo = require("bancho.adapter.SeaBeatmapRepo")
local OsuReplayConverter = require("sea.replays.OsuReplayConverter")
local ComputeContext = require("sea.compute.ComputeContext")
local ReplayBase = require("sea.replays.ReplayBase")
local Osr = require("chart.format.osu.Osr")
local _7z = require("7z")

local test = {}

local sample_osu = [[
osu file format v14

[General]
Mode: 3
AudioFilename: audio.mp3
PreviewTime: 0

[Metadata]
Title:Score Test
Artist:Adapter
Creator:Mapper
Version:Diff

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

local function encode_submission_replay(replay)
	local osr = Osr()
	---@type [integer, integer, boolean][]
	local mania_events = {}
	for i, frame in ipairs(replay.frames) do
		mania_events[i] = {
			math.floor(frame.time * 1000 + 0.5),
			frame.event.column,
			not not frame.event.value,
		}
	end
	osr:encodeManiaEvents(mania_events)

	local converter = OsuReplayConverter()
	return _7z.encode_s(converter:encodeReplayEvents(osr.events), osr.lzma_props)
end

local function create_ctx()
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:remove()
	db:open()

	local repos = Repos(db.models, SharedMemory())
	local fs = FakeFilesystem()
	local domain = Domain(repos, {osu_api = {client_id = "x", client_secret = "y", redirect_uri = "z"}}, fs)

	local user = User()
	user.id = 1
	user.name = "Player"
	user.email = "player@example.com"
	user.password = "password"
	user.latest_activity = 0
	user.created_at = 0
	repos.users_repo:createUser(user)

	local beatmap_repo = SeaBeatmapRepo(repos.charts_repo, repos.osu_repo, domain.osu_beatmaps, domain.charts_storage)

	return {
		db = db,
		repos = repos,
		fs = fs,
		domain = domain,
		beatmap_repo = beatmap_repo,
		score_repo = SeaScoreRepo(repos.users_repo, repos.charts_repo, domain.chartplay_submission, domain.charts_storage, beatmap_repo),
		replay_repo = SeaReplayRepo(repos.charts_repo, repos.users_repo, domain.replays_storage),
	}
end

---@param t testing.T
function test.submit_score_creates_canonical_chartplay(t)
	local ctx = create_ctx()
	local hash = require("digest").hash("md5", sample_osu, true)
	ctx.domain.charts_storage:set(hash, sample_osu)

	local replay = Replay()
	replay.version = 2
	replay.hash = hash
	replay.index = 1
	replay.modifiers = {}
	replay.rate = 1
	replay.mode = "mania"
	replay.nearest = true
	replay.tap_only = false
	replay.timings = Timings("osuod", 8)
	replay.subtimings = Subtimings("scorev", 1)
	replay.timing_values = assert(TimingValuesFactory:get(replay.timings, replay.subtimings))
	replay.healths = nil
	replay.columns_order = nil
	replay.custom = false
	replay.const = false
	replay.pause_count = 0
	replay.created_at = 100
	replay.rate_type = "linear"
	replay.frames = {
		{time = 0.000, event = {id = 1, column = 1, value = true}},
		{time = 0.050, event = {id = 1, column = 1, value = false}},
		{time = 1.000, event = {id = 2, column = 2, value = true}},
		{time = 1.050, event = {id = 2, column = 2, value = false}},
		{time = 2.000, event = {id = 3, column = 3, value = true}},
		{time = 2.050, event = {id = 3, column = 3, value = false}},
		{time = 3.000, event = {id = 4, column = 4, value = true}},
		{time = 3.050, event = {id = 4, column = 4, value = false}},
	}

	local replay_data = encode_submission_replay(replay)

	local score_id = assert(ctx.score_repo:submitScore({
		map_md5 = hash,
		score = 1000000,
		pp = 123.45,
		acc = 100,
		max_combo = 4,
		mods = 0,
		n300 = 0,
		n100 = 0,
		n50 = 0,
		nmiss = 0,
		ngeki = 4,
		nkatu = 0,
		grade = 8,
		status = 2,
		mode = 3,
		play_time = 100,
		time_elapsed = 4000,
		client_flags = 0,
		user_id = 1,
		perfect = true,
		online_checksum = "x",
		created_at = 100,
	}, {
		id = 777,
		set_id = 888,
		status = 2,
		od = 8,
	}, replay_data))

	local score_row = assert(ctx.score_repo:findScore(score_id))
	local scores = ctx.score_repo:findScores(hash, 3)
	local replay_back = assert(ctx.replay_repo:getReplay(score_id))
	local decoded = assert(OsuReplayConverter():fromSubmissionReplay(replay_back, hash, 1, 8, "4key", 0, 100))
	ctx.db:close()

	t:eq(score_row.user_id, 1)
	t:eq(score_row.chartplay_id ~= nil, true)
	t:eq(#scores, 1)
	t:eq(decoded.hash, hash)
	t:eq(#decoded.frames, #replay.frames)
	t:eq(ctx.fs:read("storages/charts/" .. hash), sample_osu)
	t:ne(ctx.fs:getInfo("storages/replays"), nil)
end

---@param t testing.T
function test.submit_score_hydrates_missing_chart_data(t)
	local ctx = create_ctx()
	local hash = require("digest").hash("md5", sample_osu, true)

	assert(ctx.repos.osu_repo:createBeatmap({
		id = 777,
		beatmapset_id = 888,
		hash = hash,
		status = "ranked",
		updated_at = 100,
	}))
	assert(ctx.repos.charts_repo:createUpdateChartmeta({
		hash = hash,
		index = 1,
		format = "osu",
		inputmode = 4,
		name = "Diff",
		title = "Score Test",
		artist = "Adapter",
		creator = "Mapper",
		osu_beatmap_id = 777,
		osu_beatmapset_id = 888,
		computed_at = 100,
	}, 100))
	local compute_ctx = ComputeContext()
	assert(compute_ctx:fromFileData("777.osu", sample_osu, 1))
	assert(ctx.repos.charts_repo:createUpdateChartdiff(compute_ctx:computeBase(ReplayBase()), 100))

	ctx.beatmap_repo.fetch_osu_file = function()
		return sample_osu
	end

	local replay = Replay()
	replay.version = 2
	replay.hash = hash
	replay.index = 1
	replay.modifiers = {}
	replay.rate = 1
	replay.mode = "mania"
	replay.nearest = true
	replay.tap_only = false
	replay.timings = Timings("osuod", 8)
	replay.subtimings = Subtimings("scorev", 1)
	replay.timing_values = assert(TimingValuesFactory:get(replay.timings, replay.subtimings))
	replay.healths = nil
	replay.columns_order = nil
	replay.custom = false
	replay.const = false
	replay.pause_count = 0
	replay.created_at = 100
	replay.rate_type = "linear"
	replay.frames = {
		{time = 0.000, event = {id = 1, column = 1, value = true}},
		{time = 0.050, event = {id = 1, column = 1, value = false}},
		{time = 1.000, event = {id = 2, column = 2, value = true}},
		{time = 1.050, event = {id = 2, column = 2, value = false}},
		{time = 2.000, event = {id = 3, column = 3, value = true}},
		{time = 2.050, event = {id = 3, column = 3, value = false}},
		{time = 3.000, event = {id = 4, column = 4, value = true}},
		{time = 3.050, event = {id = 4, column = 4, value = false}},
	}

	local replay_data = encode_submission_replay(replay)

	local score_id = assert(ctx.score_repo:submitScore({
		map_md5 = hash,
		score = 1000000,
		pp = 123.45,
		acc = 100,
		max_combo = 4,
		mods = 0,
		n300 = 0,
		n100 = 0,
		n50 = 0,
		nmiss = 0,
		ngeki = 4,
		nkatu = 0,
		grade = 8,
		status = 2,
		mode = 3,
		play_time = 100,
		time_elapsed = 4000,
		client_flags = 0,
		user_id = 1,
		perfect = true,
		online_checksum = "x",
		created_at = 100,
	}, {
		id = 777,
		set_id = 888,
		status = 2,
		od = 8,
	}, replay_data))
	ctx.db:close()

	t:eq(score_id > 0, true)
	t:eq(ctx.fs:read("storages/charts/" .. hash), sample_osu)
end

return test
