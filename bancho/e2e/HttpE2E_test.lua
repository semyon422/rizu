local E2EContext = require("bancho.e2e.E2EContext")
local TestLib = require("bancho.e2e.TestLib")
local BanchoProtocolResource = require("bancho.http.BanchoProtocolResource")
local OsuWebResource = require("bancho.http.OsuWebResource")
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

---@param ctx bancho.e2e.E2EContext
---@param username string
---@param password string
---@param beatmap table
---@param score_value integer
---@param created_at integer
---@param mods? integer
---@return integer
local function submit_score(ctx, username, password, beatmap, score_value, created_at, mods)
	local server, player = login_player(ctx, username, password)
	local score_data = {
		n300 = 0,
		n100 = 0,
		n50 = 0,
		ngeki = 4,
		nkatu = 0,
		nmiss = 0,
		score = score_value,
		max_combo = 4,
		perfect = true,
		grade = score_value >= 950000 and "x" or "s",
		mods = mods or 0,
		passed = true,
		mode = 3,
		play_time = tostring(created_at),
	}
	local parts = build_score_parts(
		username,
		beatmap.md5,
		"20240101",
		"test_client_hash_1234567890123456789012345678901234567890123456789012",
		"",
		score_data
	)
	local chart_response = assert(server.score_submitter:submit(player, parts, create_replay_data(beatmap.md5, created_at), {
		osuver = "20240101",
		client_hash = "test_client_hash_1234567890123456789012345678901234567890123456789012",
		sbk = "",
		st = "4000",
	}))
	return tonumber(chart_response:match("onlineScoreId:(%d+)")) or 0
end

---@param t testing.T
function test.status_online_and_matches_pages(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)
	client_a:create_match("HTTP Match", "")
	TestLib.drain(client_a)

	local resource = BanchoProtocolResource(ctx:createServer())

	local req, res, read_soc = ctx:createHttpRequest("GET", "/")
	resource:getStatus(req, res)
	local body = ctx:readHttpResponse(read_soc)
	t:ne(body:find("Running bancho server"), nil)
	t:ne(body:find("online players"), nil)
	t:ne(body:find("matches"), nil)

	req, res, read_soc = ctx:createHttpRequest("GET", "/online")
	resource:getOnline(req, res)
	body = ctx:readHttpResponse(read_soc)
	t:ne(body:find("PlayerA"), nil)
	t:ne(body:find("PlayerB"), nil)

	req, res, read_soc = ctx:createHttpRequest("GET", "/matches")
	resource:getMatches(req, res)
	body = ctx:readHttpResponse(read_soc)
	t:ne(body:find("HTTP Match"), nil)

	ctx:close()
end

---@param t testing.T
function test.osu_web_connection_and_seasonal_endpoints(t)
	local ctx = E2EContext()
	local server = ctx:createServer({
		seasonal_backgrounds = {
			{file = "bg.jpg", start = "2024-01-01", ["end"] = "2024-12-31"},
		},
	})
	local resource = OsuWebResource(server)

	local req, res, read_soc = ctx:createHttpRequest("GET", "/web/bancho_connect.php")
	resource:banchoConnect(req, res)
	t:eq(ctx:readHttpResponse(read_soc), "")

	req, res, read_soc = ctx:createHttpRequest("GET", "/web/check-updates.php")
	resource:checkUpdates(req, res)
	t:eq(ctx:readHttpResponse(read_soc), "")

	req, res, read_soc = ctx:createHttpRequest("GET", "/web/osu-getseasonal.php")
	resource:osuGetSeasonal(req, res)
	local body = ctx:readHttpResponse(read_soc)
	t:ne(body:find("bg.jpg"), nil)
	t:ne(body:find("2024%-01%-01"), nil)

	ctx:close()
end

---@param t testing.T
function test.osu_getscores_includes_personal_best_and_replay_flag(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)
	local beatmap = ctx:createBeatmap({
		id = 12345,
		set_id = 54321,
		title = "Title",
		artist = "Artist",
		version = "Insane",
		creator = "Mapper",
		mode = 3,
	})
	local personal_id = submit_score(ctx, "PlayerA", "passA", beatmap, 900000, 111, 0)
	submit_score(ctx, "PlayerB", "passB", beatmap, 950000, 222, 1)

	local client = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	t:eq(client:login().success, true)
	TestLib.drain(client)

	local server = ctx:createServer()
	local resource = OsuWebResource(server)
	local req, res, read_soc = ctx:createHttpRequest(
		"GET",
		("/web/osu-osz2-getscores.php?us=%s&ha=%s&c=%s&m=3&mods=0&v=0"):format("PlayerA", md5.sumhexa("passA"), beatmap.md5)
	)
	resource:osuGetscores(req, res, {query = {
		us = "PlayerA",
		ha = md5.sumhexa("passA"),
		c = beatmap.md5,
		m = "3",
		mods = "0",
		v = "0",
	}})
	local body = ctx:readHttpResponse(read_soc)
	local lines = {}
	for line in body:gmatch("[^\n]+") do
		lines[#lines + 1] = line
	end
	ctx:close()

	t:eq(lines[1]:find("^2|false|12345|54321|2|0|") ~= nil, true)
	t:eq(lines[2] == "0" or lines[3] == "0", true)
	t:eq(body:find("\n" .. personal_id .. "|PlayerA|") ~= nil, true)
	local personal_line = body:match("\n" .. personal_id .. "|PlayerA|[^\n]+") or ""
	t:eq(personal_line:sub(-2), "|1")
end

return test
