--- HTTP API tests: bancho_connect, seasonal, leaderboard, beatmap_search, beatmap_info, favourites

local reftest = require("bancho.reftest.init")

local M = {}

--- @param srv table Server configuration
--- @param test_username string? Test username (for auth)
--- @param test_password string? Test password (for auth)
function M.run(srv, test_username, test_password)
	local base = string.format("%s://%s:%s", srv.scheme, srv.osu_host, srv.port)
	local need_v = srv.name == "bancho.py"
	local function add_v(path)
		if not need_v then return path end
		return path:find("[?]") and path .. "&v=2" or path .. "?v=2"
	end

	-- bancho_connect.php
	local status, body = reftest.http_get(base .. add_v("/web/bancho_connect.php"))
	if status == 200 then
		reftest.record("http_bancho_connect", "PASS", string.format("HTTP %d", status))
	else
		reftest.record("http_bancho_connect", "FAIL", string.format("HTTP %d", status))
	end

	-- seasonal backgrounds
	status, body = reftest.http_get(base .. add_v("/web/osu-getseasonal.php"))
	if status == 200 then
		reftest.record("http_seasonal", "PASS", string.format("HTTP %d, %d bytes", status, #body))
	else
		reftest.record("http_seasonal", "FAIL", string.format("HTTP %d", status))
	end

	-- leaderboard (requires auth for bancho.py)
	local leaderboard_params = "b=1"
	if need_v and test_username then
		leaderboard_params = string.format("us=%s&ha=%s&%s", test_username, test_password, leaderboard_params)
	end
	status, body = reftest.http_get(base .. add_v("/web/osu-osz2-getscores.php?" .. leaderboard_params), { ["User-Agent"] = "osu!" })
	if status == 200 then
		reftest.record("http_leaderboard", "PASS", string.format("HTTP %d, %d bytes", status, #body))
	else
		reftest.record("http_leaderboard", "FAIL", string.format("HTTP %d", status))
	end

	-- beatmap search (requires auth for bancho.py)
	local search_params = "a=test"
	if need_v and test_username then
		search_params = string.format("u=%s&h=%s&%s", test_username, test_password, search_params)
	end
	status, body = reftest.http_get(base .. add_v("/web/osu-search.php?" .. search_params), { ["User-Agent"] = "osu!" })
	if status == 200 then
		reftest.record("http_beatmap_search", "PASS", string.format("HTTP %d, %d bytes", status, #body))
	else
		reftest.record("http_beatmap_search", "FAIL", string.format("HTTP %d", status))
	end

	-- beatmap info (requires auth for bancho.py)
	local beatmap_info_body = "f=test.osu"
	if need_v and test_username then
		beatmap_info_body = string.format("u=%s&h=%s&%s", test_username, test_password, beatmap_info_body)
	end
	status, body = reftest.http_post(base .. add_v("/web/osu-getbeatmapinfo.php"), beatmap_info_body, { ["User-Agent"] = "osu!" })
	if status == 200 then
		reftest.record("http_beatmap_info", "PASS", string.format("HTTP %d, %d bytes", status, #body))
	else
		reftest.record("http_beatmap_info", "FAIL", string.format("HTTP %d", status))
	end

	-- favourites (requires auth for bancho.py)
	local favourites_params = ""
	if need_v and test_username then
		favourites_params = string.format("u=%s&h=%s", test_username, test_password)
	end
	status, body = reftest.http_get(base .. add_v("/web/osu-getfavourites.php" .. (favourites_params ~= "" and "?" .. favourites_params or "")), { ["User-Agent"] = "osu!" })
	if status == 200 then
		reftest.record("http_favourites", "PASS", string.format("HTTP %d", status))
	else
		reftest.record("http_favourites", "FAIL", string.format("HTTP %d", status))
	end
end

return M
