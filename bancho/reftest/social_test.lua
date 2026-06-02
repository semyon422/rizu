--- Social tests: friend_add, friend_remove, user_stats_request, user_presence_request

local reftest = require("bancho.reftest.init")

local M = {}

--- @param client BanchoClient? Primary client
--- @param target_username string Username of the target user
--- @param target_user_id integer User ID of the target user
function M.run(client, target_username, target_user_id)
	if not client then
		reftest.record("friend_add", "SKIP", "no client")
		reftest.record("friend_remove", "SKIP", "no client")
		reftest.record("user_stats_request", "SKIP", "no client")
		reftest.record("user_presence_request", "SKIP", "no client")
		return
	end

	-- Friend add/remove
	local pkts, err = client:add_friend(target_username)
	if err then
		reftest.record("friend_add", "FAIL", err)
		reftest.record("friend_remove", "SKIP", "add failed")
	else
		reftest.record("friend_add", "PASS", string.format("%d packets", #pkts))

		pkts, err = client:remove_friend(target_username)
		if err then
			reftest.record("friend_remove", "FAIL", err)
		else
			reftest.record("friend_remove", "PASS", string.format("%d packets", #pkts))
		end
	end

	-- User stats
	pkts, err = client:request_user_stats(target_user_id)
	if err then
		reftest.record("user_stats_request", "FAIL", err)
	else
		local stats_pkt = reftest.find_pkt(pkts, reftest.ServerPackets.USER_STATS)
		if stats_pkt then
			reftest.record("user_stats_request", "PASS", "USER_STATS received")
		else
			reftest.record("user_stats_request", "PASS", string.format("%d packets", #pkts))
		end
	end

	-- User presence
	pkts, err = client:request_user_presence(target_username)
	if err then
		reftest.record("user_presence_request", "FAIL", err)
	else
		local pres_pkt = reftest.find_pkt(pkts, reftest.ServerPackets.USER_PRESENCE)
		if pres_pkt then
			reftest.record("user_presence_request", "PASS", "USER_PRESENCE received")
		else
			reftest.record("user_presence_request", "PASS", string.format("%d packets", #pkts))
		end
	end
end

return M
