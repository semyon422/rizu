--- Lobby tests: lobby_join, lobby_part

local reftest = require("bancho.reftest.init")

local M = {}

--- @param client BanchoClient? Primary client
function M.run(client)
	if not client then
		reftest.record("lobby_join", "SKIP", "no client")
		reftest.record("lobby_part", "SKIP", "no client")
		return
	end

	local pkts, err = client:join_lobby()
	if err then
		reftest.record("lobby_join", "FAIL", err)
		reftest.record("lobby_part", "SKIP", "join failed")
		return
	end
	reftest.record("lobby_join", "PASS", string.format("%d packets", #pkts))

	pkts, err = client:part_lobby()
	if err then
		reftest.record("lobby_part", "FAIL", err)
	else
		reftest.record("lobby_part", "PASS", string.format("%d packets", #pkts))
	end
end

return M
