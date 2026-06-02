--- Match advanced tests: match_password, match_mods, match_team, match_load_complete, match_has_beatmap, match_skip, match_invite, match_transfer_host, match_not_ready, match_no_beatmap

local reftest = require("bancho.reftest.init")

local M = {}

--- @param ca BanchoClient? Client A (host)
--- @param cb BanchoClient? Client B (joiner)
function M.run_password(ca, cb)
	if not ca or not cb then
		reftest.record("match_wrong_password", "SKIP", "not enough clients")
		reftest.record("match_correct_password", "SKIP", "not enough clients")
		return
	end

	-- Create with password
	local pkts, err = ca:create_match("Private", "secret123")
	if err then
		reftest.record("match_wrong_password", "FAIL", "create: " .. err)
		reftest.record("match_correct_password", "SKIP", "create failed")
		return
	end

	local match_id = reftest.get_match_id(pkts)
	if match_id == nil then
		reftest.record("match_wrong_password", "FAIL", "no match_id")
		reftest.record("match_correct_password", "SKIP", "no match_id")
		return
	end

	-- Wrong password
	pkts, err = cb:join_match(match_id, "wrong")
	if reftest.find_pkt(pkts, reftest.ServerPackets.MATCH_JOIN_FAIL) then
		reftest.record("match_wrong_password", "PASS", "rejected")
	else
		reftest.record("match_wrong_password", "FAIL", "should reject")
	end

	-- Cleanup and retry
	cb:part_match()
	ca:part_match()

	pkts, err = ca:create_match("Private2", "secret123")
	match_id = reftest.get_match_id(pkts)
	if match_id == nil then
		reftest.record("match_correct_password", "FAIL", "no match_id")
		return
	end

	pkts, err = cb:join_match(match_id, "secret123")
	if reftest.find_pkt(pkts, reftest.ServerPackets.MATCH_JOIN_SUCCESS) then
		reftest.record("match_correct_password", "PASS", "joined")
	else
		reftest.record("match_correct_password", "FAIL", "should join")
	end

	cb:part_match()
	ca:part_match()
end

--- @param ca BanchoClient? Client A (host)
--- @param cb BanchoClient? Client B (joiner)
function M.run_mods_team(ca, cb)
	if not ca or not cb then
		reftest.record("match_mods", "SKIP", "not enough clients")
		reftest.record("match_team", "SKIP", "not enough clients")
		reftest.record("match_load_complete", "SKIP", "not enough clients")
		reftest.record("match_has_beatmap", "SKIP", "not enough clients")
		return
	end

	local pkts, err = ca:create_match("Mods Test", "")
	local match_id = reftest.get_match_id(pkts)
	if match_id == nil then
		reftest.record("match_mods", "FAIL", "no match_id")
		reftest.record("match_team", "SKIP", "no match_id")
		reftest.record("match_load_complete", "SKIP", "no match_id")
		reftest.record("match_has_beatmap", "SKIP", "no match_id")
		return
	end

	cb:join_match(match_id)

	-- Mods
	pkts, err = ca:match_change_mods(1)
	if err then
		reftest.record("match_mods", "FAIL", err)
	else
		reftest.record("match_mods", "PASS", string.format("%d packets", #pkts))
	end

	-- Team
	pkts, err = cb:match_change_team(1)
	if err then
		reftest.record("match_team", "FAIL", err)
	else
		reftest.record("match_team", "PASS", string.format("%d packets", #pkts))
	end

	-- Load complete
	pkts, err = ca:match_load_complete()
	if err then
		reftest.record("match_load_complete", "FAIL", err)
	else
		reftest.record("match_load_complete", "PASS", string.format("%d packets", #pkts))
	end

	-- Has beatmap
	pkts, err = cb:match_has_beatmap()
	if err then
		reftest.record("match_has_beatmap", "FAIL", err)
	else
		reftest.record("match_has_beatmap", "PASS", string.format("%d packets", #pkts))
	end

	cb:part_match()
	ca:part_match()
end

--- @param ca BanchoClient? Client A (host)
--- @param cb BanchoClient? Client B (joiner)
function M.run_skip(ca, cb)
	if not ca or not cb then
		reftest.record("match_skip", "SKIP", "not enough clients")
		return
	end

	local pkts, err = ca:create_match("Skip Test", "")
	local match_id = reftest.get_match_id(pkts)
	if match_id == nil then
		reftest.record("match_skip", "FAIL", "no match_id")
		return
	end

	cb:join_match(match_id)
	ca:match_ready()
	cb:match_ready()

	pkts, err = ca:match_skip()
	if err then
		reftest.record("match_skip", "FAIL", err)
	else
		reftest.record("match_skip", "PASS", string.format("%d packets", #pkts))
	end

	cb:part_match()
	ca:part_match()
end

--- @param ca BanchoClient? Client A (host)
--- @param cb BanchoClient? Client B (joiner)
function M.run_invite(ca, cb)
	if not ca or not cb then
		reftest.record("match_invite", "SKIP", "not enough clients")
		return
	end

	local pkts, err = ca:match_invite(cb.config.username)
	if err then
		reftest.record("match_invite", "FAIL", err)
	else
		reftest.record("match_invite", "PASS", string.format("%d packets", #pkts))
	end
end

--- @param ca BanchoClient? Client A (host)
--- @param cb BanchoClient? Client B (joiner)
function M.run_transfer_host(ca, cb)
	if not ca or not cb then
		reftest.record("match_transfer_host", "SKIP", "not enough clients")
		return
	end

	local pkts, err = ca:create_match("Transfer Test", "")
	local match_id = reftest.get_match_id(pkts)
	if match_id == nil then
		reftest.record("match_transfer_host", "FAIL", "no match_id")
		return
	end

	cb:join_match(match_id)

	pkts, err = ca:match_transfer_host()
	if err then
		reftest.record("match_transfer_host", "FAIL", err)
	else
		reftest.record("match_transfer_host", "PASS", string.format("%d packets", #pkts))
	end

	cb:part_match()
	ca:part_match()
end

--- @param ca BanchoClient? Client A (host)
--- @param cb BanchoClient? Client B (joiner)
function M.run_states(ca, cb)
	if not ca or not cb then
		reftest.record("match_not_ready", "SKIP", "not enough clients")
		reftest.record("match_no_beatmap", "SKIP", "not enough clients")
		return
	end

	local pkts, err = ca:create_match("States Test", "")
	local match_id = reftest.get_match_id(pkts)
	if match_id == nil then
		reftest.record("match_not_ready", "FAIL", "no match_id")
		reftest.record("match_no_beatmap", "SKIP", "no match_id")
		return
	end

	cb:join_match(match_id)

	pkts, err = cb:match_not_ready()
	if err then
		reftest.record("match_not_ready", "FAIL", err)
	else
		reftest.record("match_not_ready", "PASS", string.format("%d packets", #pkts))
	end

	pkts, err = cb:match_no_beatmap()
	if err then
		reftest.record("match_no_beatmap", "FAIL", err)
	else
		reftest.record("match_no_beatmap", "PASS", string.format("%d packets", #pkts))
	end

	cb:part_match()
	ca:part_match()
end

return M
