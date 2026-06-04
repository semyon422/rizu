--- Web page tests: status_page, online_page, matches_page

local reftest = require("bancho.reftest.init")

local M = {}

--- @param srv table Server configuration
function M.run(srv)
	local status, body = reftest.http_get(string.format("%s://%s:%s/", srv.scheme, srv.host, srv.port))
	if status == 200 then
		reftest.record("status_page", "PASS", string.format("HTTP %d, %d bytes", status, #body))
	else
		reftest.record("status_page", "FAIL", string.format("HTTP %d", status))
	end

	status, body = reftest.http_get(string.format("%s://%s:%s/online", srv.scheme, srv.host, srv.port))
	if status == 200 then
		reftest.record("online_page", "PASS", string.format("HTTP %d, %d bytes", status, #body))
	else
		reftest.record("online_page", "FAIL", string.format("HTTP %d", status))
	end

	status, body = reftest.http_get(string.format("%s://%s:%s/matches", srv.scheme, srv.host, srv.port))
	if status == 200 then
		reftest.record("matches_page", "PASS", string.format("HTTP %d, %d bytes", status, #body))
	else
		reftest.record("matches_page", "FAIL", string.format("HTTP %d", status))
	end
end

return M
