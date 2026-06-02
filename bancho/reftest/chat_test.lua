--- Chat tests: chat_join, chat_send, chat_part

local reftest = require("bancho.reftest.init")

local M = {}

--- @param client BanchoClient? Primary client
function M.run(client)
	if not client then
		reftest.record("chat_join", "SKIP", "no client")
		reftest.record("chat_send", "SKIP", "no client")
		reftest.record("chat_part", "SKIP", "no client")
		return
	end

	local pkts, err = client:join_channel("#general")
	if err then
		reftest.record("chat_join", "FAIL", err)
		reftest.record("chat_send", "SKIP", "join failed")
		reftest.record("chat_part", "SKIP", "join failed")
		return
	end

	local chan = reftest.get_channel_name(pkts)
	if chan then
		reftest.record("chat_join", "PASS", chan)
	else
		reftest.record("chat_join", "FAIL", "no CHANNEL_JOIN_SUCCESS")
		reftest.record("chat_send", "SKIP", "join failed")
		reftest.record("chat_part", "SKIP", "join failed")
		return
	end

	pkts, err = client:send_message("#general", "Feature test")
	if err then
		reftest.record("chat_send", "FAIL", err)
	else
		reftest.record("chat_send", "PASS", string.format("%d packets", #pkts))
	end

	pkts, err = client:part_channel("#general")
	if err then
		reftest.record("chat_part", "FAIL", err)
	else
		reftest.record("chat_part", "PASS", string.format("%d packets", #pkts))
	end
end

return M
