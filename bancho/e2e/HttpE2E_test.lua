local E2EContext = require("bancho.e2e.E2EContext")
local TestLib = require("bancho.e2e.TestLib")
local BanchoProtocolResource = require("bancho.http.BanchoProtocolResource")
local OsuWebResource = require("bancho.http.OsuWebResource")
local md5 = require("md5")

local test = {}

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
		db_path = ":memory:",
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
	local user_id = ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	local other_user_id = ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)
	local repos = require("bancho.db.repos")(ctx.db.models)
	local bmap_md5 = "11111111111111111111111111111111"
	repos.beatmap_repo:addBeatmap({
		id = 12345,
		set_id = 54321,
		md5 = bmap_md5,
		artist = "Artist",
		title = "Title",
		version = "Insane",
		creator = "Mapper",
		status = 2,
		mode = 3,
	})
	local personal_id = repos.score_repo:addScore({
		map_md5 = bmap_md5,
		score = 900000,
		pp = 100,
		acc = 98.5,
		max_combo = 500,
		mods = 0,
		n300 = 400,
		n100 = 20,
		n50 = 5,
		nmiss = 1,
		ngeki = 50,
		nkatu = 10,
		grade = 6,
		status = 2,
		mode = 3,
		play_time = 111,
		time_elapsed = 60000,
		client_flags = 0,
		user_id = user_id,
		perfect = false,
		online_checksum = "",
	})
	repos.replay_repo:saveReplay(personal_id, "replay")
	repos.score_repo:addScore({
		map_md5 = bmap_md5,
		score = 950000,
		pp = 120,
		acc = 99,
		max_combo = 600,
		mods = 0,
		n300 = 450,
		n100 = 10,
		n50 = 1,
		nmiss = 0,
		ngeki = 60,
		nkatu = 5,
		grade = 8,
		status = 2,
		mode = 3,
		play_time = 222,
		time_elapsed = 60000,
		client_flags = 0,
		user_id = other_user_id,
		perfect = true,
		online_checksum = "",
	})

	local client = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	t:eq(client:login().success, true)
	TestLib.drain(client)

	local server = ctx:createServer()
	local resource = OsuWebResource(server)
	local req, res, read_soc = ctx:createHttpRequest(
		"GET",
		("/web/osu-osz2-getscores.php?us=%s&ha=%s&c=%s&m=3&mods=0&v=0"):format("PlayerA", md5.sumhexa("passA"), bmap_md5)
	)
	resource:osuGetscores(req, res, {query = {
		us = "PlayerA",
		ha = md5.sumhexa("passA"),
		c = bmap_md5,
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
	t:eq(body:find("|" .. user_id .. "|2|111|1") ~= nil, true)
	t:eq(body:find("PlayerB") ~= nil, true)
end

return test
