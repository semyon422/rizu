local E2EContext = require("bancho.e2e.E2EContext")
local TestLib = require("bancho.e2e.TestLib")
local Binary = require("bancho.protocol.Binary")
local ServerPackets = require("bancho.protocol.ServerPackets")
local erfunc = require("chart.scoring.erfunc")
local Leaderboard = require("sea.leaderboards.Leaderboard")
local LeaderboardUser = require("sea.leaderboards.LeaderboardUser")
local digest = require("digest")

local test = {}

local function create_osu_pp_leaderboard(ctx, mode)
	local leaderboard = Leaderboard()
	leaderboard.name = "chart.osu." .. mode
	leaderboard.rating_calc = "pp"
	leaderboard.mode = mode
	return ctx.repos.leaderboards_repo:createLeaderboard(leaderboard)
end

local function encode_accuracy(norm_accuracy)
	return 0.032 / (erfunc.erfinv(norm_accuracy) * math.sqrt(2))
end

local function create_leaderboard_user(ctx, leaderboard_id, user_id, total_rating, total_accuracy, total_plays, rank)
	local leaderboard_user = LeaderboardUser()
	leaderboard_user.leaderboard_id = leaderboard_id
	leaderboard_user.user_id = user_id
	leaderboard_user.total_rating = total_rating
	leaderboard_user.total_accuracy = encode_accuracy(total_accuracy)
	leaderboard_user.total_plays = total_plays
	leaderboard_user.ranked_plays = total_plays
	leaderboard_user.rank = rank
	leaderboard_user.updated_at = 0
	ctx.repos.leaderboards_repo:createLeaderboardUser(leaderboard_user)
end

---@param t testing.T
function test.login(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("TestUser", digest.hash("md5", "testpass", true), 0)

	local client = TestLib.createClient(ctx, "TestUser", digest.hash("md5", "testpass", true))
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
	ctx:createUser("TestUser", digest.hash("md5", "correct", true), 0)

	local client = TestLib.createClient(ctx, "TestUser", digest.hash("md5", "wrong", true))
	t:eq(client:login().success, false)

	ctx:close()
end

---@param t testing.T
function test.login_sends_ranked_presence_and_normalized_stats(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("TestUser", digest.hash("md5", "testpass", true), 0)
	local leaderboard = create_osu_pp_leaderboard(ctx, "osu")
	create_leaderboard_user(ctx, leaderboard.id, user_id, 456.8, 0.9876, 0, 321)

	local client = TestLib.createClient(ctx, "TestUser", digest.hash("md5", "testpass", true))
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
	local user_a = ctx:createUser("PlayerA", digest.hash("md5", "passA", true), 0)
	local user_b = ctx:createUser("PlayerB", digest.hash("md5", "passB", true), 0)
	local repos = ctx.bancho_repos
	repos.friends_repo:addFriend(user_a, user_b)

	local client = TestLib.createClient(ctx, "PlayerA", digest.hash("md5", "passA", true))
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
	local user_id = ctx:createUser("RestrictedUser", digest.hash("md5", "testpass", true), 0)
	local repos = ctx.bancho_repos
	repos.user_repo:partialUpdate(user_id, {is_restricted = true})

	local client = TestLib.createClient(ctx, "RestrictedUser", digest.hash("md5", "testpass", true))
	local result = client:login()
	t:eq(result.success, true)
	t:ne(TestLib.findPacket(result.packets, ServerPackets.ACCOUNT_RESTRICTED), nil)

	ctx:close()
end

---@param t testing.T
function test.change_action_sends_updated_stats_to_self(t)
	local ctx = E2EContext()
	local user_id = ctx:createUser("TestUser", digest.hash("md5", "testpass", true), 0)
	local leaderboard = create_osu_pp_leaderboard(ctx, "mania")
	create_leaderboard_user(ctx, leaderboard.id, user_id, 321.0, 0.975, 12, 123)

	local client = TestLib.createClient(ctx, "TestUser", digest.hash("md5", "testpass", true))
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
	ctx:createUser("PlayerA", digest.hash("md5", "passA", true), 0)
	ctx:createUser("PlayerB", digest.hash("md5", "passB", true), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", digest.hash("md5", "passA", true))
	local client_b = TestLib.createClient(ctx, "PlayerB", digest.hash("md5", "passB", true))
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
	local user_id = ctx:createUser("PlayerA", digest.hash("md5", "passA", true), 0)
	local repos = ctx.bancho_repos

	local client = TestLib.createClient(ctx, "PlayerA", digest.hash("md5", "passA", true))
	t:eq(client:login().success, true)
	TestLib.drain(client)

	local _, err = client:receive_updates(2)
	t:eq(err, nil)

	local user = repos.user_repo:findUser(user_id)
	t:eq(user.pres_filter, 2)

	ctx:close()
end

return test
