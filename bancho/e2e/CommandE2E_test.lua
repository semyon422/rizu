local E2EContext = require("bancho.e2e.E2EContext")
local TestLib = require("bancho.e2e.TestLib")
local ServerPackets = require("bancho.protocol.ServerPackets")
local digest = require("digest")

local test = {}

---@param t testing.T
function test.match_command_start_solo(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", digest.hash("md5", "passA", true), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", digest.hash("md5", "passA", true))
	t:eq(client_a:login().success, true)
	TestLib.drain(client_a)

	local pkts_a = select(1, client_a:create_match("Solo Start", ""))
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.MATCH_JOIN_SUCCESS), nil)

	pkts_a = select(1, client_a:send_message("#multiplayer", "!mp start"))
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.MATCH_START), nil)
	t:eq(TestLib.extractMessage(pkts_a), "Good luck!")

	ctx:close()
end

---@param t testing.T
function test.match_command_start_force(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", digest.hash("md5", "passA", true), 0)
	ctx:createUser("PlayerB", digest.hash("md5", "passB", true), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", digest.hash("md5", "passA", true))
	local client_b = TestLib.createClient(ctx, "PlayerB", digest.hash("md5", "passB", true))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local match_id = TestLib.extractMatchId(select(1, client_a:create_match("Force Start", "")))
	client_b:join_match(match_id)
	TestLib.drain(client_a)
	TestLib.drain(client_b)
	client_a:match_ready()
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a = select(1, client_a:send_message("#multiplayer", "!mp start force"))
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.MATCH_START), nil)
	t:eq(TestLib.extractMessage(pkts_a), "Good luck!")

	ctx:close()
end

---@param t testing.T
function test.match_command_start_requires_host(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", digest.hash("md5", "passA", true), 0)
	ctx:createUser("PlayerB", digest.hash("md5", "passB", true), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", digest.hash("md5", "passA", true))
	local client_b = TestLib.createClient(ctx, "PlayerB", digest.hash("md5", "passB", true))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local match_id = TestLib.extractMatchId(select(1, client_a:create_match("Host Only", "")))
	client_b:join_match(match_id)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_b = select(1, client_b:send_message("#multiplayer", "!mp start"))
	t:eq(TestLib.extractMessage(pkts_b), "Only the host can start the match.")
	t:eq(TestLib.findPacket(pkts_b, ServerPackets.MATCH_START), nil)

	ctx:close()
end

---@param t testing.T
function test.match_command_start_requires_ready_or_force(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", digest.hash("md5", "passA", true), 0)
	ctx:createUser("PlayerB", digest.hash("md5", "passB", true), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", digest.hash("md5", "passA", true))
	local client_b = TestLib.createClient(ctx, "PlayerB", digest.hash("md5", "passB", true))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local match_id = TestLib.extractMatchId(select(1, client_a:create_match("Ready Check", "")))
	client_b:join_match(match_id)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a = select(1, client_a:send_message("#multiplayer", "!mp start"))
	t:eq(TestLib.extractMessage(pkts_a), "Not all players are ready (`!mp start force` to override).")
	t:eq(TestLib.findPacket(pkts_a, ServerPackets.MATCH_START), nil)

	ctx:close()
end

---@param t testing.T
function test.match_command_transfer_host(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", digest.hash("md5", "passA", true), 0)
	ctx:createUser("PlayerB", digest.hash("md5", "passB", true), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", digest.hash("md5", "passA", true))
	local client_b = TestLib.createClient(ctx, "PlayerB", digest.hash("md5", "passB", true))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local match_id = TestLib.extractMatchId(select(1, client_a:create_match("Host Transfer", "")))
	client_b:join_match(match_id)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a = select(1, client_a:send_message("#multiplayer", "!mp host PlayerB"))
	t:eq(TestLib.extractMessage(pkts_a), "Match host transferred.")

	local pkts_b = select(1, client_b:ping())
	t:ne(TestLib.findPacket(pkts_b, ServerPackets.MATCH_TRANSFER_HOST), nil)

	ctx:close()
end

---@param t testing.T
function test.match_command_transfer_host_requires_host(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", digest.hash("md5", "passA", true), 0)
	ctx:createUser("PlayerB", digest.hash("md5", "passB", true), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", digest.hash("md5", "passA", true))
	local client_b = TestLib.createClient(ctx, "PlayerB", digest.hash("md5", "passB", true))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local match_id = TestLib.extractMatchId(select(1, client_a:create_match("Host Check", "")))
	client_b:join_match(match_id)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_b = select(1, client_b:send_message("#multiplayer", "!mp host PlayerA"))
	t:eq(TestLib.extractMessage(pkts_b), "Only the host can transfer host.")

	ctx:close()
end

---@param t testing.T
function test.match_command_transfer_host_invalid_target(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", digest.hash("md5", "passA", true), 0)
	ctx:createUser("PlayerB", digest.hash("md5", "passB", true), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", digest.hash("md5", "passA", true))
	local client_b = TestLib.createClient(ctx, "PlayerB", digest.hash("md5", "passB", true))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local match_id = TestLib.extractMatchId(select(1, client_a:create_match("Host Check", "")))
	client_b:join_match(match_id)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a = select(1, client_a:send_message("#multiplayer", "!mp host MissingUser"))
	t:eq(TestLib.extractMessage(pkts_a), "Player not found in match.")

	ctx:close()
end

return test
