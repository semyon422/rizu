--- Login tests: login, login_packets, auto_join_channels

local reftest = require("bancho.reftest.init")

local M = {}

--- @param srv table Server configuration
--- @param username string Test username
--- @param password string Test password
--- @return BanchoClient? client
--- @return integer? user_id
function M.run(srv, username, password)
	reftest.ensure_deps()

	-- Login using BanchoClient which returns packets from the FIRST login.
	-- (Calling transport:login() again sends a SECOND login which bancho.py
	-- treats differently because the session already exists.)
	local config = reftest.ClientConfig {
		host = srv.host,
		port = srv.port,
		scheme = srv.scheme,
		username = username,
		password_md5 = reftest.md5.sumhexa(password),
	}
	local client = reftest.BanchoClient(config)
	local result = client:login()

	if not result.success then
		reftest.record("login", "FAIL", result.error or "login failed")
		reftest.record("login_packets", "SKIP", "login failed")
		reftest.record("auto_join_channels", "SKIP", "login failed")
		return nil
	end
	reftest.record("login", "PASS", string.format("user_id=%d", result.user_id))

	-- Login packets: use packets from the FIRST login (result.packets).
	local login_pkts = result.packets
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

	-- Store login packets for later use (e.g., channel discovery).
	client.login_packets = result.packets
	return client, result.user_id
end

return M
