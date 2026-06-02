--- Messaging tests: private_message

local reftest = require("bancho.reftest.init")

local M = {}

--- @param ca BanchoClient? Client A (sender)
--- @param cb BanchoClient? Client B (receiver)
function M.run(ca, cb)
	if not ca or not cb then
		reftest.record("private_message", "SKIP", "not enough clients")
		return
	end

	local pkts, err = ca:send_private_message(cb.config.username, "Hello!")
	if err then
		reftest.record("private_message", "FAIL", err)
	else
		reftest.record("private_message", "PASS", string.format("%d packets", #pkts))
	end
end

return M
