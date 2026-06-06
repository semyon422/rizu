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

return test
