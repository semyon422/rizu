local E2EContext = require("bancho.e2e.E2EContext")
local TestLib = require("bancho.e2e.TestLib")
local Action = require("bancho.constants.Action")
local Binary = require("bancho.protocol.Binary")
local ServerPackets = require("bancho.protocol.ServerPackets")
local md5 = require("md5")

local test = {}

---@param t testing.T
function test.chat_message(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	client_a:join_channel("#general")
	client_b:join_channel("#general")
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local _, err = client_a:send_message("#general", "Hello from A!")
	t:eq(err, nil)

	local pkts_b, _ = client_b:ping()
	t:eq(TestLib.extractMessage(pkts_b), "Hello from A!")

	ctx:close()
end

---@param t testing.T
function test.match_chat(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a = select(1, client_a:create_match("Chat Test", ""))
	local match_id = TestLib.extractMatchId(pkts_a)
	t:ne(match_id, nil)
	local pkts_b = select(1, client_b:join_match(match_id))
	t:ne(TestLib.findPacket(pkts_b, ServerPackets.MATCH_JOIN_SUCCESS), nil)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	client_a:send_message("#multiplayer", "GG in match!")
	pkts_b = select(1, client_b:ping())
	t:eq(TestLib.extractMessage(pkts_b), "GG in match!")

	ctx:close()
end

---@param t testing.T
function test.private_message_delivery(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a, err = client_a:send_private_message("PlayerB", "hello dm")
	t:eq(err, nil)
	t:eq(TestLib.findPacket(pkts_a, ServerPackets.SEND_MESSAGE), nil)

	local pkts_b, _ = client_b:ping()
	local msg = TestLib.extractMessageData(pkts_b)
	t:ne(msg, nil)
	t:eq(msg.text, "hello dm")
	t:eq(msg.sender, "PlayerA")
	t:eq(msg.recipient, "PlayerB")

	ctx:close()
end

---@param t testing.T
function test.private_message_blocked(t)
	local ctx = E2EContext()
	local user_a = ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	local user_b = ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local server = ctx:createServer()
	local target = server.players:get(nil, user_b)
	t:ne(target, nil)
	target.blocks = {user_a}
	server.players:updatePlayer(target)

	local pkts_a, err = client_a:send_private_message("PlayerB", "blocked")
	t:eq(err, nil)
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.USER_DM_BLOCKED), nil)

	local pkts_b, _ = client_b:ping()
	t:eq(TestLib.findPacket(pkts_b, ServerPackets.SEND_MESSAGE), nil)

	ctx:close()
end

---@param t testing.T
function test.private_message_requires_friend_when_pm_private(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"), {pm_private = true})
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a, err = client_a:send_private_message("PlayerB", "blocked by privacy")
	t:eq(err, nil)
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.USER_DM_BLOCKED), nil)

	ctx:close()
end

---@param t testing.T
function test.private_message_to_silenced_target(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	local user_b = ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)
	local repos = ctx.bancho_repos
	repos.user_repo:partialUpdate(user_b, {silence_end = os.time() + 60})

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a, err = client_a:send_private_message("PlayerB", "are you there")
	t:eq(err, nil)
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.TARGET_IS_SILENCED), nil)

	ctx:close()
end

---@param t testing.T
function test.private_message_returns_away_message(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	client_b:set_away_message("brb")
	client_b:update_status(0, Action.AFK, "away", "", 0, 0)
	TestLib.drain(client_b)

	local pkts_a, err = client_a:send_private_message("PlayerB", "ping")
	t:eq(err, nil)
	local away = TestLib.extractMessageData(pkts_a)
	t:ne(away, nil)
	t:eq(away.text, "brb")
	t:eq(away.sender, "PlayerB")

	local pkts_b, _ = client_b:ping()
	local dm = TestLib.extractMessageData(pkts_b)
	t:ne(dm, nil)
	t:eq(dm.text, "ping")

	ctx:close()
end

return test
