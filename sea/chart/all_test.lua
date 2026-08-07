local table_util = require("table_util")
local digest = require("digest")
local Chartplay = require("sea.chart.Chartplay")
local Chartdiff = require("sea.chart.Chartdiff")
local Chartplays = require("sea.chart.Chartplays")
local ChartplaySubmission = require("sea.chart.ChartplaySubmission")
local TableStorage = require("sea.chart.storage.TableStorage")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local Healths = require("sea.chart.Healths")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local FakeComputeDataProvider = require("sea.compute.FakeComputeDataProvider")
local ComputeDataProvider = require("sea.compute.ComputeDataProvider")
local ComputeDataLoader = require("sea.compute.ComputeDataLoader")
local ReplayComputer = require("sea.compute.ReplayComputer")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local ChartfilesRepo = require("sea.chart.repos.ChartfilesRepo")
local Users = require("sea.access.Users")
local UsersRepo = require("sea.access.repos.UsersRepo")
local UserInsecure = require("sea.access.UserInsecure")
local Leaderboards = require("sea.leaderboards.Leaderboards")
local LeaderboardsRepo = require("sea.leaderboards.repos.LeaderboardsRepo")
local UserActivityGraph = require("sea.activity.UserActivityGraph")
local ActivityRepo = require("sea.activity.repos.ActivityRepo")
local ExternalRanked = require("sea.difftables.ExternalRanked")
local Dans = require("sea.dan.Dans")
local DanClearsRepo = require("sea.dan.repos.DanClearsRepo")
local FakePasswordHasher = require("sea.access.FakePasswordHasher")

local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local User = require("sea.access.User")
local Replay = require("sea.replays.Replay")
local ReplayCoder = require("sea.replays.ReplayCoder")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
local InputMode = require("chart.core.InputMode")

local test = {}

local function create_test_ctx()
	local db = ServerSqliteDatabase(LjsqliteDatabase())

	db.path = ":memory:"

	db:remove()
	db:open()

	-- db.orm:debug(true)

	local models = db.models

	local charts_repo = ChartsRepo(models)
	local chartfiles_repo = ChartfilesRepo(models)
	local users_repo = UsersRepo(models)
	local leaderboards_repo = LeaderboardsRepo(models)
	local activity_repo = ActivityRepo(models)
	local dan_clears_repo = DanClearsRepo(models)

	local charts_storage = TableStorage()
	local replays_storage = TableStorage()

	local compute_data_provider = ComputeDataProvider(chartfiles_repo, charts_storage, replays_storage)
	local compute_data_loader = ComputeDataLoader(compute_data_provider)

	local chartplays = Chartplays(
		charts_repo,
		chartfiles_repo,
		compute_data_provider,
		charts_storage,
		replays_storage,
		ReplayComputer(),
		"test"
	)

	local leaderboards = Leaderboards(leaderboards_repo)
	local users = Users(users_repo, FakePasswordHasher(), nil)
	local dans = Dans(charts_repo, dan_clears_repo)
	local user_activity_graph = UserActivityGraph(activity_repo)
	local external_ranked = ExternalRanked(nil, nil)
	-- Mock external_ranked:submit to do nothing
	external_ranked.submit = function() end

	local submission = ChartplaySubmission(chartplays, leaderboards, users, dans, user_activity_graph, external_ranked)

	local user = User()
	user.id = 1

	return {
		db = db,
		charts_repo = charts_repo,
		chartfiles_repo = chartfiles_repo,
		users_repo = users_repo,
		chartplays = chartplays,
		leaderboards = leaderboards,
		users = users,
		submission = submission,
		user = user,
	}
end

local chartfile_name = "chart.sph"
local chartfile_data = [[
# metadata
title Title
artist Artist
name Name
creator Creator
audio audio.mp3
input 4key

# notes
1000 =0
0100
0010
0001
1000 =4
]]

---@type rizu.ReplayFrame[]
local frames = {
	{time = 0.01, event = VirtualInputEvent(1, true, 2)},
	{time = 0.1, event = VirtualInputEvent(1, false, 2)},
	{time = 0.95, event = VirtualInputEvent(1, true, 3)},
	{time = 1.1, event = VirtualInputEvent(1, false, 3)},
}

---@type sea.Replay
local replay = {
	version = 2,
	timing_values = assert(TimingValuesFactory:get(Timings("osuod", 8))),
	frames = frames,
	created_at = 0,
	--
	hash = digest.hash("md5", chartfile_data, true),
	index = 1,
	modifiers = {},
	rate = 1,
	mode = "mania",
	--
	nearest = true,
	tap_only = false,
	timings = Timings("osuod", 8),
	subtimings = Subtimings("scorev", 1),
	healths = nil,
	columns_order = {4, 1, 2, 3},
	--
	custom = false,
	const = false,
	pause_count = 0,
	rate_type = "linear",
}
setmetatable(replay, Replay)
local _replayfile_data = assert(ReplayCoder.encode(replay))

local _chartplay_values = {
	hash = replay.hash,
	index = replay.index,
	modifiers = replay.modifiers,
	rate = replay.rate,
	mode = replay.mode,
	--
	nearest = replay.nearest,
	tap_only = replay.tap_only,
	timings = replay.timings,
	subtimings = replay.subtimings,
	healths = replay.healths,
	columns_order = replay.columns_order,
	--
	custom = replay.custom,
	const = replay.const,
	pause_count = replay.pause_count,
	created_at = replay.created_at,
	rate_type = replay.rate_type,
	--
	accuracy = 0.059305293410162315815,
	replay_hash = digest.hash("md5", _replayfile_data, true),
	judges = {1, 0, 1, 0, 0, 3},
	max_combo = 2,
	miss_count = 3,
	not_perfect_count = 4,
	rating = 0.0037594122723929000729,
	rating_msd = 0.20617003738880157471,
	rating_pp = 0,
	pass = true,
}
setmetatable(_chartplay_values, Chartplay)
---@cast _chartplay_values sea.Chartplay

local _chartdiff_values = {
	hash = digest.hash("md5", chartfile_data, true),
	index = 1,
	modifiers = {},
	rate = 1,
	mode = "mania",
	inputmode = "4key",
	duration = 4,
	start_time = 0,
	notes_count = 5,
	judges_count = 5,
	note_types_count = {hold = 0, tap = 5},
	density_data = {},
	sv_data = {},
	enps_diff = 0.0091578194443670893,
	osu_diff = 0.30224240623872012,
	msd_diff = 1.7960339784622192383,
	msd_diff_data = {
		overall = 1.7960339784622192383,
		stream = 1.7960339784622192383,
		jumpstream = 1.2650580406188964844,
		handstream = 1.2186338901519775391,
		stamina = 1.3666554689407348633,
		jackspeed = 0.15087868273258209229,
		chordjack = 1.1722098588943481445,
		technical = 1.357906341552734375,
	},
	msd_diff_rates = {},
	user_diff = 0,
	user_diff_data = "",
	notes_preview = string.char(1, 0, 0, 64, 0, 193, 64, 194, 64, 196, 64, 200, 64, 4, 193),
}
setmetatable(_chartdiff_values, Chartdiff)
---@cast _chartdiff_values sea.Chartdiff

---@param t testing.T
function test.submit_valid_score(t)
	local ctx = create_test_ctx()

	local replayfile_data_table = setmetatable(table_util.copy(replay), Replay)
	local replayfile_data = _replayfile_data
	t:assert(replayfile_data_table:validate())

	local compute_data_provider = FakeComputeDataProvider()
	compute_data_provider:addChart(replay.hash, chartfile_name, chartfile_data)
	compute_data_provider:addReplay(digest.hash("md5", replayfile_data, true), replayfile_data)
	local compute_data_loader = ComputeDataLoader(compute_data_provider)

	local chartplay_values = setmetatable(table_util.copy(_chartplay_values), Chartplay)
	local chartdiff_values = setmetatable(table_util.copy(_chartdiff_values), Chartdiff)

	local valid, errs = chartplay_values:validate()
	t:tdeq({valid, errs}, {true})

	local valid, errs = chartdiff_values:validate()
	t:tdeq({valid, errs}, {true})

	local user = User()
	user.id = 1

	local c, err = ctx.chartplays:submit(user, 0, compute_data_provider, chartplay_values, chartdiff_values)

	if t:assert(c, err) then
		---@cast c -?
		t:assert(c.chartplay.user_id)
		t:assert(c.chartplay.compute_state == "valid")
	end

	c, err = ctx.chartplays:submit(user, 0, compute_data_provider, chartplay_values, chartdiff_values)
	t:eq(c, nil)
	t:eq(err, "can submit: rate limit")

	local interval = ctx.chartplays.chartplays_access.submit_interval
	c, err = ctx.chartplays:submit(user, interval, compute_data_provider, chartplay_values, chartdiff_values)
	t:assert(c, err)
end

---@param t testing.T
function test.submit_chartplay_save_on_retrieval_failure(t)
	local ctx = create_test_ctx()

	local user_values = UserInsecure()
	user_values.name = "test"
	user_values.email = "test@test.com"
	user_values.password = "password"

	local res, err = ctx.users:register(User(), "127.0.0.1", 1000, user_values)
	t:assert(res, "Registration should succeed: " .. tostring(err))
	---@cast res -?
	local user = res.user

	-- Provider that will return nil for everything
	local compute_data_provider = FakeComputeDataProvider()
	local remote = {compute_data_provider = compute_data_provider, client = {setLeaderboardUsers = function() end}}

	local chartplay_values = setmetatable(table_util.copy(_chartplay_values), Chartplay)
	local chartdiff_values = setmetatable(table_util.copy(_chartdiff_values), Chartdiff)

	local peer = {user = user, remote = remote}
	local res, err = ctx.submission:submitChartplay(peer, chartplay_values, chartdiff_values)
	---@cast err -?

	t:eq(res, nil, "Submission should have failed due to retrieval error")
	t:assert(err:find("not found"), "Error message should reflect retrieval failure, got: " .. tostring(err))

	-- Verify partial save: chartplays table should contain the record
	local count = ctx.charts_repo:countChartplays()
	t:eq(count, 1, "Chartplay should be saved even if retrieval fails")

	local chartplay = ctx.charts_repo:getRecentChartplays(user.id, 1)[1]
	t:assert(chartplay, "Chartplay record should exist")
	t:eq(chartplay.compute_state, "invalid", "Chartplay state should be 'invalid' due to processing failure")
end

return test
