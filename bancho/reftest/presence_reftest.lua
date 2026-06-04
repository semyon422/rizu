--- Presence tests: ping, status_update, away_message, change_action, receive_updates, all_presences

local reftest = require("bancho.reftest.init")

local M = {}

--- @param client BanchoClient? Primary client
function M.run(client)
	if not client then
		reftest.record("ping", "SKIP", "no client")
		reftest.record("status_update", "SKIP", "no client")
		reftest.record("away_message", "SKIP", "no client")
		reftest.record("change_action", "SKIP", "no client")
		reftest.record("receive_updates", "SKIP", "no client")
		reftest.record("all_presences", "SKIP", "no client")
		return
	end

	local pkts, err = client:ping()
	if err then
		reftest.record("ping", "FAIL", err)
	else
		reftest.record("ping", "PASS", string.format("%d packets", #pkts))
	end

	pkts, err = client:update_status(3, 0, "Testing", "", 0, 0)
	if err then
		reftest.record("status_update", "FAIL", err)
	else
		reftest.record("status_update", "PASS", string.format("%d packets", #pkts))
	end

	pkts, err = client:set_away_message("Away testing")
	if err then
		reftest.record("away_message", "FAIL", err)
	else
		reftest.record("away_message", "PASS", string.format("%d packets", #pkts))
	end

	pkts, err = client:change_action(0)
	if err then
		reftest.record("change_action", "FAIL", err)
	else
		reftest.record("change_action", "PASS", string.format("%d packets", #pkts))
	end

	pkts, err = client:receive_updates(0, true)
	if err then
		reftest.record("receive_updates", "FAIL", err)
	else
		reftest.record("receive_updates", "PASS", string.format("%d packets", #pkts))
	end

	pkts, err = client:request_all_presences()
	if err then
		reftest.record("all_presences", "FAIL", err)
	else
		reftest.record("all_presences", "PASS", string.format("%d packets", #pkts))
	end
end

return M
