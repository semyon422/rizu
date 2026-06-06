local E2EContext = require("bancho.e2e.E2EContext")
local TestLib = require("bancho.e2e.TestLib")
local ClientPackets = require("bancho.protocol.ClientPackets")
local ServerPackets = require("bancho.protocol.ServerPackets")
local md5 = require("md5")

local test = {}

---@param t testing.T
function test.start_and_stop_spectating(t)
	local ctx = E2EContext()
	local user_a = ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_b, err = client_b:start_spectating(user_a)
	t:eq(err, nil)
	t:eq(#pkts_b, 0)

	local pkts_a = select(1, client_a:ping())
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.SPECTATOR_JOINED), nil)

	pkts_b, err = client_b:stop_spectating()
	t:eq(err, nil)
	t:eq(#pkts_b, 0)

	pkts_a = select(1, client_a:ping())
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.SPECTATOR_LEFT), nil)

	ctx:close()
end

---@param t testing.T
function test.switch_spectating_target(t)
	local ctx = E2EContext()
	local user_a = ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	local user_b = ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)
	local user_c = ctx:createUser("PlayerC", md5.sumhexa("passC"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	local client_c = TestLib.createClient(ctx, "PlayerC", md5.sumhexa("passC"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	t:eq(client_c:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)
	TestLib.drain(client_c)

	client_b:start_spectating(user_a)
	TestLib.drain(client_a)

	local pkts_b = select(1, client_b:start_spectating(user_c))
	t:eq(#pkts_b, 0)

	local pkts_a = select(1, client_a:ping())
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.SPECTATOR_LEFT), nil)

	local pkts_c = select(1, client_c:ping())
	t:ne(TestLib.findPacket(pkts_c, ServerPackets.SPECTATOR_JOINED), nil)

	ctx:close()
end

---@param t testing.T
function test.fellow_spectator_notifications(t)
	local ctx = E2EContext()
	local user_a = ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)
	ctx:createUser("PlayerC", md5.sumhexa("passC"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	local client_c = TestLib.createClient(ctx, "PlayerC", md5.sumhexa("passC"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	t:eq(client_c:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)
	TestLib.drain(client_c)

	client_b:start_spectating(user_a)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	client_c:start_spectating(user_a)
	TestLib.drain(client_a)

	local pkts_b = select(1, client_b:ping())
	t:ne(TestLib.findPacket(pkts_b, ServerPackets.FELLOW_SPECTATOR_JOINED), nil)

	client_c:stop_spectating()
	TestLib.drain(client_a)

	pkts_b = select(1, client_b:ping())
	t:ne(TestLib.findPacket(pkts_b, ServerPackets.FELLOW_SPECTATOR_LEFT), nil)

	ctx:close()
end

---@param t testing.T
function test.spectate_frames_are_relayed(t)
	local ctx = E2EContext()
	local user_a = ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	client_b:start_spectating(user_a)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local frame_data = "spectate-frame-data"
	local packet = client_a:build_packet(ClientPackets.SPECTATE_FRAMES, frame_data)
	local _, err = client_a:send(packet)
	t:eq(err, nil)

	local pkts_b = select(1, client_b:ping())
	local pkt = TestLib.findPacket(pkts_b, ServerPackets.SPECTATE_FRAMES)
	t:ne(pkt, nil)
	t:eq(pkt.body, frame_data)

	ctx:close()
end

return test
