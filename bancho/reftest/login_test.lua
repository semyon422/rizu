--- Login tests: login, login_packets, auto_join_channels

local reftest = require("bancho.reftest.init")

local M = {}

--- @param srv table Server configuration
--- @param username string Test username
--- @param password string Test password
function M.run(srv, username, password)
	reftest.ensure_deps()

	-- Login
	local client, uid = reftest.login(srv, username, password)
	if not client then
		reftest.record("login", "FAIL", "login failed")
		reftest.record("login_packets", "SKIP", "login failed")
		reftest.record("auto_join_channels", "SKIP", "login failed")
		return nil
	end
	reftest.record("login", "PASS", string.format("user_id=%d", uid))

	-- Login packets: use the SAME client's transport (avoid session replacement)
	local login_pkts, err = client.transport:login_and_parse()
	if err then
		reftest.record("login_packets", "FAIL", err)
	else
		local expected_ids = {
			[reftest.ServerPackets.USER_ID] = "USER_ID",
			[reftest.ServerPackets.PRIVILEGES] = "PRIVILEGES",
			[reftest.ServerPackets.NOTIFICATION] = "NOTIFICATION",
			[reftest.ServerPackets.CHANNEL_INFO_END] = "CHANNEL_INFO_END",
			[reftest.ServerPackets.FRIENDS_LIST] = "FRIENDS_LIST",
			[reftest.ServerPackets.SILENCE_END] = "SILENCE_END",
			[reftest.ServerPackets.USER_PRESENCE] = "USER_PRESENCE",
			[reftest.ServerPackets.USER_STATS] = "USER_STATS",
		}
		local found = {}
		for _, pkt in ipairs(login_pkts) do found[pkt.id] = true end
		local missing = {}
		for id, name in pairs(expected_ids) do
			if not found[id] then table.insert(missing, name) end
		end
		if #missing == 0 then
			reftest.record("login_packets", "PASS", string.format("all %d packets present", #login_pkts))
		else
			reftest.record("login_packets", "FAIL", "missing: " .. table.concat(missing, ", "))
		end
	end

	-- Auto-join: check login response for channel packets
	local auto_count, info_count = 0, 0
	for _, pkt in ipairs(login_pkts) do
		if pkt.id == reftest.ServerPackets.CHANNEL_AUTO_JOIN then auto_count = auto_count + 1 end
		if pkt.id == reftest.ServerPackets.CHANNEL_INFO then info_count = info_count + 1 end
	end
	if auto_count > 0 or info_count > 0 then
		reftest.record("auto_join_channels", "PASS", string.format("auto=%d info=%d", auto_count, info_count))
	else
		reftest.record("auto_join_channels", "FAIL", "no channel packets")
	end

	return client, uid
end

return M
