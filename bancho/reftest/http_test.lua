--- HTTP API tests: bancho_connect, seasonal, leaderboard, beatmap_search, beatmap_info, favourites

local reftest = require("bancho.reftest.init")

local M = {}

--- @param srv table Server configuration
--- @param test_username string? Test username (for auth)
--- @param test_password_md5 string? Test password MD5 hash (for auth)
function M.run(srv, test_username, test_password_md5)
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

	-- leaderboard (requires auth for bancho.py: us=username, ha=password_md5)
	-- Also needs: s, vv, v, c, f, m, i, mods, h
	local leaderboard_params = "b=1&s=0&vv=2&m=0&i=0&mods=0&a=0&c=00000000000000000000000000000000&f=test.osu&h=00000000000000000000000000000000"
	if need_v and test_username then
		leaderboard_params = string.format("us=%s&ha=%s&%s", test_username, test_password_md5, leaderboard_params)
	end
	status, body = reftest.http_get(base .. add_v("/web/osu-osz2-getscores.php?" .. leaderboard_params), { ["User-Agent"] = "osu!" })
	if status == 200 then
		reftest.record("http_leaderboard", "PASS", string.format("HTTP %d, %d bytes", status, #body))
	else
		reftest.record("http_leaderboard", "FAIL", string.format("HTTP %d", status))
	end

	-- beatmap search (requires auth for bancho.py: u=username, h=password_md5)
	-- Also needs: r, q, m, p
	local search_params = "r=4&q=test&m=-1&p=0"
	if need_v and test_username then
		search_params = string.format("u=%s&h=%s&%s", test_username, test_password_md5, search_params)
	end
	status, body = reftest.http_get(base .. add_v("/web/osu-search.php?" .. search_params), { ["User-Agent"] = "osu!" })
	if status == 200 then
		reftest.record("http_beatmap_search", "PASS", string.format("HTTP %d, %d bytes", status, #body))
	else
		reftest.record("http_beatmap_search", "FAIL", string.format("HTTP %d", status))
	end

	-- beatmap info (requires auth for bancho.py: u=h in query, JSON body with Filenames/Ids)
	-- authenticate_player_session(Query, "u", "h") means u/h must be in query string
	-- OsuBeatmapRequestForm is a Pydantic model = JSON body
	local beatmap_url = base .. "/web/osu-getbeatmapinfo.php"
	if need_v and test_username then
		beatmap_url = beatmap_url .. string.format("?v=2&u=%s&h=%s", test_username, test_password_md5)
	end
	local beatmap_info_body = '{"Filenames":["test.osu"],"Ids":[0]}'
	status, body = reftest.http_post(beatmap_url, beatmap_info_body, { ["User-Agent"] = "osu!", ["Content-Type"] = "application/json" })
	if status == 200 then
		reftest.record("http_beatmap_info", "PASS", string.format("HTTP %d, %d bytes", status, #body))
	else
		reftest.record("http_beatmap_info", "FAIL", string.format("HTTP %d", status))
	end

	-- favourites (requires auth for bancho.py: u=username, h=password_md5)
	local favourites_params = ""
	if need_v and test_username then
		favourites_params = string.format("u=%s&h=%s", test_username, test_password_md5)
	end
	status, body = reftest.http_get(base .. add_v("/web/osu-getfavourites.php" .. (favourites_params ~= "" and "?" .. favourites_params or "")), { ["User-Agent"] = "osu!" })
	if status == 200 then
		reftest.record("http_favourites", "PASS", string.format("HTTP %d", status))
	else
		reftest.record("http_favourites", "FAIL", string.format("HTTP %d", status))
	end
end

return M
