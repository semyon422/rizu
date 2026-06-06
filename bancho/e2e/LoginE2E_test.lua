local E2EContext = require("bancho.e2e.E2EContext")
local TestLib = require("bancho.e2e.TestLib")
local Repos = require("bancho.db.repos")
local Binary = require("bancho.protocol.Binary")
local ServerPackets = require("bancho.protocol.ServerPackets")
local md5 = require("md5")

local test = {}

---@param t testing.T
function test.login(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("TestUser", md5.sumhexa("testpass"), 0)

	local client = TestLib.createClient(ctx, "TestUser", md5.sumhexa("testpass"))
	local result = client:login()
	t:eq(result.success, true)
	t:ne(result.user_id, -1)

	local user_pkt = TestLib.findPacket(result.packets, ServerPackets.USER_ID)
	t:ne(user_pkt, nil)
	t:eq(Binary.readI32(user_pkt.body, 1), user_id)

	ctx:close()
end

---@param t testing.T
function test.login_wrong_password(t)
	local ctx = E2EContext()
	ctx:createUser("TestUser", md5.sumhexa("correct"), 0)

	local client = TestLib.createClient(ctx, "TestUser", md5.sumhexa("wrong"))
	t:eq(client:login().success, false)

	ctx:close()
end

---@param t testing.T
function test.login_sends_ranked_presence_and_normalized_stats(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("TestUser", md5.sumhexa("testpass"), 0)
	local repos = Repos(ctx.db.models)
	repos.stats_repo:updateStats(user_id, 0, {
		rank = 321,
		acc = 98.76,
		pp = 456,
	})

	local client = TestLib.createClient(ctx, "TestUser", md5.sumhexa("testpass"))
	local result = client:login()
	t:eq(result.success, true)

	local presence_pkt = TestLib.findPacket(result.packets, ServerPackets.USER_PRESENCE)
	t:eq(TestLib.extractPresenceRank(presence_pkt), 321)

	local stats_pkt = TestLib.findPacket(result.packets, ServerPackets.USER_STATS)
	t:aeq(TestLib.extractStatsAccuracy(stats_pkt), 0.9876, 0.0001)

	ctx:close()
end

---@param t testing.T
function test.login_sends_friends_list_and_autojoin_packets(t)
	local ctx = E2EContext()
	local user_a = ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	local user_b = ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)
	local repos = Repos(ctx.db.models)
	repos.friends_repo:addFriend(user_a, user_b)

	local client = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local result = client:login()
	t:eq(result.success, true)

	local friends_pkt = TestLib.findPacket(result.packets, ServerPackets.FRIENDS_LIST)
	t:ne(friends_pkt, nil)
	local friends = TestLib.extractFriendsList(friends_pkt)
	t:eq(#friends, 1)
	t:eq(friends[1], user_b)

	local auto_join = 0
	for _, pkt in ipairs(result.packets) do
		if pkt.id == ServerPackets.CHANNEL_AUTO_JOIN then
			auto_join = auto_join + 1
		end
	end
	t:ne(auto_join, 0)

	ctx:close()
end

---@param t testing.T
function test.restricted_login_sends_account_restricted_packet(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("RestrictedUser", md5.sumhexa("testpass"), 0)
	local repos = Repos(ctx.db.models)
	repos.user_repo:partialUpdate(user_id, {is_restricted = true})

	local client = TestLib.createClient(ctx, "RestrictedUser", md5.sumhexa("testpass"))
	local result = client:login()
	t:eq(result.success, true)
	t:ne(TestLib.findPacket(result.packets, ServerPackets.ACCOUNT_RESTRICTED), nil)

	ctx:close()
end

---@param t testing.T
function test.change_action_sends_updated_stats_to_self(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("TestUser", md5.sumhexa("testpass"), 0)
	local repos = Repos(ctx.db.models)
	repos.stats_repo:updateStats(user_id, 3, {
		plays = 12,
		acc = 97.5,
		pp = 321,
		rank = 123,
	})

	local client = TestLib.createClient(ctx, "TestUser", md5.sumhexa("testpass"))
	t:eq(client:login().success, true)
	TestLib.drain(client)

	local pkts = select(1, client:update_status(3, 0, "", "", 0, 0))
	local stats_pkt = TestLib.findPacket(pkts, ServerPackets.USER_STATS)
	t:ne(stats_pkt, nil)
	t:aeq(TestLib.extractStatsAccuracy(stats_pkt), 0.975, 0.0001)

	ctx:close()
end

---@param t testing.T
function test.user_presence_request_all_returns_online_users(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts = select(1, client_a:request_all_presences())
	local presence_count = 0
	for _, pkt in ipairs(pkts) do
		if pkt.id == ServerPackets.USER_PRESENCE then
			presence_count = presence_count + 1
		end
	end
	t:eq(presence_count, 2)

	ctx:close()
end

---@param t testing.T
function test.receive_updates_persists_preference(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	local repos = Repos(ctx.db.models)

	local client = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	t:eq(client:login().success, true)
	TestLib.drain(client)

	local _, err = client:receive_updates(2)
	t:eq(err, nil)

	local user = repos.user_repo:findUser(user_id)
	t:eq(user.pres_filter, 2)

	ctx:close()
end

return test
