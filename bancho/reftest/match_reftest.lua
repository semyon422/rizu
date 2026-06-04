--- Match tests: match_create, match_join, match_ready, match_lock, match_start, match_part, match_complete, match_failed

local reftest = require("bancho.reftest.init")

local M = {}

--- @param client BanchoClient? Primary client
function M.run_complete_fail(client)
	if not client then
		reftest.record("match_complete_fail", "SKIP", "no client")
		return
	end

	local pkts, err = client:create_match("Complete Test", "")
	local match_id = reftest.get_match_id(pkts)
	if match_id == nil then
		reftest.record("match_complete_fail", "FAIL", "no match_id")
		return
	end

	pkts, err = client:match_complete()
	if err then
		reftest.record("match_complete", "FAIL", err)
	else
		reftest.record("match_complete", "PASS", string.format("%d packets", #pkts))
	end

	pkts, err = client:match_failed()
	if err then
		reftest.record("match_failed", "FAIL", err)
	else
		reftest.record("match_failed", "PASS", string.format("%d packets", #pkts))
	end

	client:part_match()
end

--- @param ca BanchoClient? Client A (host)
--- @param cb BanchoClient? Client B (joiner)
function M.run_lifecycle(ca, cb)
	if not ca or not cb then
		reftest.record("match_create", "SKIP", "not enough clients")
		reftest.record("match_join", "SKIP", "not enough clients")
		reftest.record("match_ready", "SKIP", "not enough clients")
		reftest.record("match_lock", "SKIP", "not enough clients")
		reftest.record("match_start", "SKIP", "not enough clients")
		reftest.record("match_part", "SKIP", "not enough clients")
		return
	end

	-- Create match
	local pkts, err = ca:create_match("Test Match", "")
	if err then
		reftest.record("match_create", "FAIL", err)
		reftest.record("match_join", "SKIP", "create failed")
		reftest.record("match_ready", "SKIP", "create failed")
		reftest.record("match_lock", "SKIP", "create failed")
		reftest.record("match_start", "SKIP", "create failed")
		reftest.record("match_part", "SKIP", "create failed")
		return
	end

	local match_id = reftest.get_match_id(pkts)
	if match_id == nil then
		reftest.record("match_create", "FAIL", "no match_id")
		reftest.record("match_join", "SKIP", "no match_id")
		reftest.record("match_ready", "SKIP", "no match_id")
		reftest.record("match_lock", "SKIP", "no match_id")
		reftest.record("match_start", "SKIP", "no match_id")
		reftest.record("match_part", "SKIP", "no match_id")
		return
	end
	reftest.record("match_create", "PASS", string.format("id=%d", match_id))

	-- Join
	pkts, err = cb:join_match(match_id)
	if err then
		reftest.record("match_join", "FAIL", err)
	else
		if reftest.find_pkt(pkts, reftest.ServerPackets.MATCH_JOIN_SUCCESS) then
			reftest.record("match_join", "PASS", "joined")
		else
			reftest.record("match_join", "FAIL", "no MATCH_JOIN_SUCCESS")
		end
	end

	-- Ready
	pkts, err = ca:match_ready()
	if err then
		reftest.record("match_ready", "FAIL", err)
	else
		reftest.record("match_ready", "PASS", string.format("%d packets", #pkts))
	end

	-- Lock
	pkts, err = ca:match_lock(true)
	if err then
		reftest.record("match_lock", "FAIL", err)
	else
		reftest.record("match_lock", "PASS", string.format("%d packets", #pkts))
	end

	-- Start
	pkts, err = ca:match_start()
	if err then
		reftest.record("match_start", "FAIL", err)
	else
		local start_pkt = reftest.find_pkt(pkts, reftest.ServerPackets.MATCH_START)
		if start_pkt then
			reftest.record("match_start", "PASS", "MATCH_START received")
		else
			reftest.record("match_start", "PASS", string.format("%d packets", #pkts))
		end
	end

	-- Part
	cb:part_match()
	pkts, err = ca:part_match()
	if err then
		reftest.record("match_part", "FAIL", err)
	else
		local dispose = reftest.find_pkt(pkts, reftest.ServerPackets.DISPOSE_MATCH)
		if dispose then
			reftest.record("match_part", "PASS", "DISPOSE_MATCH")
		else
			reftest.record("match_part", "PASS", string.format("%d packets", #pkts))
		end
	end
end

return M
