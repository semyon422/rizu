local erfunc = require("chart.scoring.erfunc")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local UsersRepo = require("sea.access.repos.UsersRepo")
local LeaderboardsRepo = require("sea.leaderboards.repos.LeaderboardsRepo")
local UserInsecure = require("sea.access.UserInsecure")
local Leaderboard = require("sea.leaderboards.Leaderboard")
local LeaderboardUser = require("sea.leaderboards.LeaderboardUser")
local SeaStatsRepo = require("bancho.adapter.SeaStatsRepo")

local test = {}

local function create_ctx()
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:remove()
	db:open()

	local users_repo = UsersRepo(db.models)
	local leaderboards_repo = LeaderboardsRepo(db.models)
	local repo = SeaStatsRepo(users_repo, leaderboards_repo)

	return {
		db = db,
		users_repo = users_repo,
		leaderboards_repo = leaderboards_repo,
		repo = repo,
	}
end

local function create_user(ctx, name, email)
	local user = UserInsecure()
	user.name = name
	user.email = email
	user.password = "password"
	user.latest_activity = 0
	user.created_at = 0
	user.play_time = 123
	return ctx.users_repo:createUser(user)
end

local function create_osu_pp_leaderboard(ctx, name, mode)
	local leaderboard = Leaderboard()
	leaderboard.name = name
	leaderboard.rating_calc = "pp"
	leaderboard.mode = mode
	return ctx.leaderboards_repo:createLeaderboard(leaderboard)
end

---@param t testing.T
function test.get_stats_uses_osu_pp_leaderboard(t)
	local ctx = create_ctx()
	local user = create_user(ctx, "user", "user@example.com")
	local leaderboard = create_osu_pp_leaderboard(ctx, "chart.osu.mania", "mania")

	local leaderboard_user = LeaderboardUser()
	leaderboard_user.leaderboard_id = leaderboard.id
	leaderboard_user.user_id = user.id
	leaderboard_user.total_rating = 456.8
	leaderboard_user.total_accuracy = 0.032 / (erfunc.erfinv(0.5) * math.sqrt(2))
	leaderboard_user.total_plays = 77
	leaderboard_user.ranked_plays = 66
	leaderboard_user.rank = 12
	leaderboard_user.updated_at = 0
	ctx.leaderboards_repo:createLeaderboardUser(leaderboard_user)

	local stats = assert(ctx.repo:getStats(user.id, 3))
	ctx.db:close()

	t:eq(stats.pp, 456)
	t:eq(math.floor(stats.acc + 0.5), 50)
	t:eq(stats.plays, 77)
	t:eq(stats.rank, 12)
	t:eq(stats.playtime, 123)
end

---@param t testing.T
function test.get_stats_falls_back_to_stubs(t)
	local ctx = create_ctx()
	local user = create_user(ctx, "user", "user@example.com")

	local stats = assert(ctx.repo:getStats(user.id, 2))
	local rank = ctx.repo:getGlobalRank(user.id, 2, 100)
	ctx.db:close()

	t:eq(stats.pp, 0)
	t:eq(stats.rank, 0)
	t:eq(stats.playtime, 123)
	t:eq(rank, 0)
end

---@param t testing.T
function test.get_global_rank_uses_existing_rank_or_count(t)
	local ctx = create_ctx()
	local user1 = create_user(ctx, "user1", "user1@example.com")
	local user2 = create_user(ctx, "user2", "user2@example.com")
	local leaderboard = create_osu_pp_leaderboard(ctx, "chart.osu.osu", "osu")

	local leaderboard_user = LeaderboardUser()
	leaderboard_user.leaderboard_id = leaderboard.id
	leaderboard_user.user_id = user1.id
	leaderboard_user.total_rating = 500
	leaderboard_user.total_accuracy = 0
	leaderboard_user.total_plays = 1
	leaderboard_user.ranked_plays = 1
	leaderboard_user.rank = 1
	leaderboard_user.updated_at = 0
	ctx.leaderboards_repo:createLeaderboardUser(leaderboard_user)

	local rank_existing = ctx.repo:getGlobalRank(user1.id, 0, 500)
	local rank_counted = ctx.repo:getGlobalRank(user2.id, 0, 400)
	ctx.db:close()

	t:eq(rank_existing, 1)
	t:eq(rank_counted, 2)
end

return test
