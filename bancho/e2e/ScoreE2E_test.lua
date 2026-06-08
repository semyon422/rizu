local E2EContext = require("bancho.e2e.E2EContext")
local BanchoProtocolResource = require("bancho.http.BanchoProtocolResource")
local ExtendedStringSocket = require("bancho.e2e.ExtendedStringSocket")
local Request = require("web.http.Request")
local Response = require("web.http.Response")
local Grade = require("bancho.constants.Grade")
local Score = require("bancho.model.Score")
local Replay = require("sea.replays.Replay")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local OsuReplayConverter = require("sea.replays.OsuReplayConverter")
local Osr = require("chart.format.osu.Osr")
local _7z = require("7z")
local md5 = require("md5")

local test = {}

---@param replay sea.Replay
---@return string
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

---@param hash string
---@param created_at integer
---@return string
local function create_replay_data(hash, created_at)
	local offset = (created_at % 10) * 0.001
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
	replay.created_at = created_at
	replay.rate_type = "linear"
	replay.frames = {
		{time = 0.000 + offset, event = {id = 1, column = 1, value = true}},
		{time = 0.050 + offset, event = {id = 1, column = 1, value = false}},
		{time = 1.000 + offset, event = {id = 2, column = 2, value = true}},
		{time = 1.050 + offset, event = {id = 2, column = 2, value = false}},
		{time = 2.000 + offset, event = {id = 3, column = 3, value = true}},
		{time = 2.050 + offset, event = {id = 3, column = 3, value = false}},
		{time = 3.000 + offset, event = {id = 4, column = 4, value = true}},
		{time = 3.050 + offset, event = {id = 4, column = 4, value = false}},
	}
	return encode_submission_replay(replay)
end

---@param ctx bancho.e2e.E2EContext
---@param username string
---@param password string
---@return bancho.server.BanchoServer
---@return bancho.model.Player
local function login_player(ctx, username, password)
	local server = ctx:createServer()
	local proto_resource = BanchoProtocolResource(server)
	local login_soc = ExtendedStringSocket()
	local login_res_soc = login_soc:split()
	local login_body = table.concat({
		username,
		md5.sumhexa(password),
		"b20240101|0|0|hash1:adapters:hash2:hash3:hash4:|0",
	}, "\n") .. "\n"
	local login_request = {
		"POST / HTTP/1.1",
		"Host: osu.example.com",
		"Content-Length: " .. #login_body,
		"",
		login_body,
	}
	login_res_soc:send(table.concat(login_request, "\r\n"))

	local login_req = Request(login_soc, "r")
	local login_res = Response(login_res_soc, "w")
	proto_resource:handleProtocol(login_req, login_res)

	local player = server.players:get(nil, nil, username)
	return server, player
end

---@param username string
---@param bmap_md5 string
---@param osu_version string
---@param client_hash string
---@param storyboard_md5 string
---@param score_data table
---@return string[]
local function build_score_parts(username, bmap_md5, osu_version, client_hash, storyboard_md5, score_data)
	local temp_score = Score:new()
	temp_score.n300 = score_data.n300
	temp_score.n100 = score_data.n100
	temp_score.n50 = score_data.n50
	temp_score.ngeki = score_data.ngeki
	temp_score.nkatu = score_data.nkatu
	temp_score.nmiss = score_data.nmiss
	temp_score.score = score_data.score
	temp_score.max_combo = score_data.max_combo
	temp_score.perfect = score_data.perfect
	temp_score.grade = Grade.fromString(score_data.grade)
	temp_score.mods = score_data.mods
	temp_score.passed = score_data.passed
	temp_score.mode = score_data.mode
	temp_score.client_time = score_data.play_time

	local checksum = temp_score:computeOnlineChecksum(username, bmap_md5, osu_version, client_hash, storyboard_md5)

	return {
		bmap_md5,
		username,
		checksum,
		tostring(score_data.n300),
		tostring(score_data.n100),
		tostring(score_data.n50),
		tostring(score_data.ngeki),
		tostring(score_data.nkatu),
		tostring(score_data.nmiss),
		tostring(score_data.score),
		tostring(score_data.max_combo),
		score_data.perfect and "True" or "False",
		score_data.grade,
		tostring(score_data.mods),
		score_data.passed and "True" or "False",
		tostring(score_data.mode),
		score_data.play_time,
	}
end

---@param t testing.T
function test.score_submission(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("TestUser", md5.sumhexa("testpass"), 0)
	local repos = ctx.bancho_repos
	local bmap = ctx:createBeatmap({
		id = 12345,
		set_id = 1234,
		title = "TestTitle",
		artist = "TestArtist",
		version = "Easy",
		creator = "TestCreator",
		mode = 3,
		od = 7,
	})

	local server, player = login_player(ctx, "TestUser", "testpass")
	t:ne(player, nil)
	t:eq(player.id, user_id)

	local score_data = {
		n300 = 0,
		n100 = 0,
		n50 = 0,
		ngeki = 4,
		nkatu = 0,
		nmiss = 0,
		score = 999999,
		max_combo = 4,
		perfect = true,
		grade = "x",
		mods = 0,
		passed = true,
		mode = 3,
		play_time = "240101120000",
	}
	local osu_version = "20240101"
	local client_hash = "test_client_hash_1234567890123456789012345678901234567890123456789012"
	local storyboard_md5 = ""
	local parts = build_score_parts("TestUser", bmap.md5, osu_version, client_hash, storyboard_md5, score_data)
	local fields = {
		osuver = osu_version,
		client_hash = client_hash,
		sbk = storyboard_md5,
		st = "4000",
	}

	local chart_response = server.score_submitter:submit(player, parts, create_replay_data(bmap.md5, 100), fields)
	t:ne(chart_response, nil)
	t:ne(chart_response, "")

	local saved_score = repos.score_repo:findBestScore(bmap.md5, user_id, score_data.mode)
	t:ne(saved_score, nil)
	t:eq(saved_score.score, 1000000)
	t:eq(saved_score.ngeki, score_data.ngeki)
	t:eq(saved_score.nmiss, score_data.nmiss)
	t:eq(saved_score.grade, Grade.X.value)

	ctx:close()
end

---@param t testing.T
function test.stats_persistence(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("StatsUser", md5.sumhexa("testpass"), 0)
	local repos = ctx.bancho_repos
	local bmap = ctx:createBeatmap({
		id = 12345,
		set_id = 1234,
		title = "StatsTitle",
		artist = "StatsArtist",
		version = "Easy",
		creator = "StatsCreator",
		mode = 3,
		od = 7,
	})

	local server, player = login_player(ctx, "StatsUser", "testpass")
	t:ne(player, nil)

	local score_data = {
		n300 = 0,
		n100 = 0,
		n50 = 0,
		ngeki = 4,
		nkatu = 0,
		nmiss = 0,
		score = 999999,
		max_combo = 4,
		perfect = true,
		grade = "x",
		mods = 0,
		passed = true,
		mode = 3,
		play_time = "240101120000",
	}
	local osu_version = "20240101"
	local client_hash = "test_client_hash_1234567890123456789012345678901234567890123456789012"
	local storyboard_md5 = ""
	local parts = build_score_parts("StatsUser", bmap.md5, osu_version, client_hash, storyboard_md5, score_data)
	local fields = {
		osuver = osu_version,
		client_hash = client_hash,
		sbk = storyboard_md5,
		st = "4000",
	}

	local chart_response = server.score_submitter:submit(player, parts, create_replay_data(bmap.md5, 100), fields)
	t:ne(chart_response, nil)

	local db_stats = repos.stats_repo:getStats(user_id, 3)
	t:ne(db_stats, nil)
	t:eq(db_stats.plays, 0)
	t:eq(db_stats.tscore, 0)
	t:eq(db_stats.rscore, 0)
	t:eq(db_stats.x_count, 0)
	t:eq(db_stats.s_count, 0)
	t:eq(db_stats.a_count, 0)

	local server2 = ctx:createServer()
	local proto_resource2 = BanchoProtocolResource(server2)
	local login_soc2 = ExtendedStringSocket()
	local login_res_soc2 = login_soc2:split()
	local login_body = table.concat({
		"StatsUser",
		md5.sumhexa("testpass"),
		"b20240101|0|0|hash1:adapters:hash2:hash3:hash4:|0",
	}, "\n") .. "\n"
	local login_request = {
		"POST / HTTP/1.1",
		"Host: osu.example.com",
		"Content-Length: " .. #login_body,
		"",
		login_body,
	}
	login_res_soc2:send(table.concat(login_request, "\r\n"))
	local login_req2 = Request(login_soc2, "r")
	local login_res2 = Response(login_res_soc2, "w")
	proto_resource2:handleProtocol(login_req2, login_res2)

	local player2 = server2.players:get(nil, nil, "StatsUser")
	t:ne(player2, nil)
	local db_stats2 = repos.stats_repo:getStats(user_id, 3)
	t:ne(db_stats2, nil)
	t:eq(db_stats2.plays, 0)
	t:eq(db_stats2.tscore, 0)

	ctx:close()
end

return test
