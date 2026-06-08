local E2EContext = require("bancho.e2e.E2EContext")
local TestLib = require("bancho.e2e.TestLib")
local erfunc = require("chart.scoring.erfunc")
local ServerPackets = require("bancho.protocol.ServerPackets")
local Leaderboard = require("sea.leaderboards.Leaderboard")
local LeaderboardUser = require("sea.leaderboards.LeaderboardUser")
local md5 = require("md5")

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
function test.friend_add_remove(t)
	local ctx = E2EContext()
	local user_a = ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	local user_b = ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)
	local repos = ctx.bancho_repos

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a = select(1, client_a:add_friend(user_b))
	t:eq(repos.friends_repo:isFriend(user_a, user_b), true)
	t:ne(TestLib.findPacket(pkts_a, ServerPackets.USER_PRESENCE), nil)

	client_a:remove_friend(user_b)
	t:eq(repos.friends_repo:isFriend(user_a, user_b), false)

	ctx:close()
end

---@param t testing.T
function test.user_stats_and_presence_request(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	local user_b = ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)
	local leaderboard = create_osu_pp_leaderboard(ctx, "osu")
	create_leaderboard_user(ctx, leaderboard.id, user_b, 456.8, 0.985, 0, 123)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts = select(1, client_a:request_user_stats(user_b))
	local stats_pkt = TestLib.findPacket(pkts, ServerPackets.USER_STATS)
	t:ne(stats_pkt, nil)
	t:aeq(TestLib.extractStatsAccuracy(stats_pkt), 0.985, 0.0001)

	pkts = select(1, client_a:request_user_presence(user_b))
	local presence_pkt = TestLib.findPacket(pkts, ServerPackets.USER_PRESENCE)
	t:ne(presence_pkt, nil)
	t:eq(TestLib.extractPresenceRank(presence_pkt), 123)

	ctx:close()
end

---@param t testing.T
function test.join_lobby_receives_existing_matches(t)
	local ctx = E2EContext()
	ctx:createUser("PlayerA", md5.sumhexa("passA"), 0)
	ctx:createUser("PlayerB", md5.sumhexa("passB"), 0)

	local client_a = TestLib.createClient(ctx, "PlayerA", md5.sumhexa("passA"))
	local client_b = TestLib.createClient(ctx, "PlayerB", md5.sumhexa("passB"))
	t:eq(client_a:login().success, true)
	t:eq(client_b:login().success, true)
	TestLib.drain(client_a)
	TestLib.drain(client_b)

	local pkts_a = select(1, client_a:create_match("Lobby Test", ""))
	t:ne(TestLib.extractMatchId(pkts_a), nil)

	local pkts_b = select(1, client_b:join_lobby())
	t:ne(TestLib.findPacket(pkts_b, ServerPackets.NEW_MATCH), nil)

	pkts_b = select(1, client_b:part_lobby())
	t:eq(#pkts_b, 0)

	ctx:close()
end

return test
