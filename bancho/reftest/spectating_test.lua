--- Spectating tests: spectating, spectate_stop

local reftest = require("bancho.reftest.init")

local M = {}

--- @param ca BanchoClient? Client A (spectator)
--- @param cb BanchoClient? Client B (target)
function M.run(ca, cb)
	if not ca or not cb then
		reftest.record("spectating", "SKIP", "not enough clients")
		reftest.record("spectate_stop", "SKIP", "not enough clients")
		return
	end

	local pkts, err = ca:start_spectating(cb.user_id)
	if err then
		reftest.record("spectating", "FAIL", err)
	else
		local joined = reftest.find_pkt(pkts, reftest.ServerPackets.SPECTATOR_JOINED)
		if joined then
			reftest.record("spectating", "PASS", "SPECTATOR_JOINED")
		else
			reftest.record("spectating", "PASS", string.format("%d packets", #pkts))
		end
	end

	pkts, err = ca:stop_spectating()
	if err then
		reftest.record("spectate_stop", "FAIL", err)
	else
		reftest.record("spectate_stop", "PASS", string.format("%d packets", #pkts))
	end
end

return M
