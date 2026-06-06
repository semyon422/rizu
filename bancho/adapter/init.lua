local BanchoDatabase = require("bancho.db.BanchoDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local Repos = require("bancho.db.repos")

local SeaUserRepo = require("bancho.adapter.SeaUserRepo")
local SeaFriendsRepo = require("bancho.adapter.SeaFriendsRepo")
local SeaFavouritesRepo = require("bancho.adapter.SeaFavouritesRepo")
local SeaStatsRepo = require("bancho.adapter.SeaStatsRepo")

local BanchoAdapter = {}

BanchoAdapter.SeaUserRepo = SeaUserRepo
BanchoAdapter.SeaFriendsRepo = SeaFriendsRepo
BanchoAdapter.SeaFavouritesRepo = SeaFavouritesRepo
BanchoAdapter.SeaStatsRepo = SeaStatsRepo

---@param server bancho.server.BanchoServer
---@param path string?
---@param users_repo? sea.UsersRepo
---@param leaderboards_repo? sea.LeaderboardsRepo
---@return bancho.BanchoDatabase
---@return bancho.Repos
function BanchoAdapter.setupLegacyDatabase(server, path, users_repo, leaderboards_repo)
	local db = BanchoDatabase(LjsqliteDatabase())
	if path then
		db.path = path
	end
	db:open()

	local repos = Repos(db.models)
	local user_repo = users_repo and SeaUserRepo(users_repo) or repos.user_repo
	local friends_repo = users_repo and SeaFriendsRepo(users_repo) or repos.friends_repo
	local favourites_repo = users_repo and SeaFavouritesRepo(users_repo) or repos.favourites_repo
	local stats_repo = users_repo and leaderboards_repo and SeaStatsRepo(users_repo, leaderboards_repo) or repos.stats_repo

	server.db = db
	server:setRepos(
		user_repo,
		repos.score_repo,
		repos.beatmap_repo,
		friends_repo,
		favourites_repo,
		stats_repo,
		repos.replay_repo
	)

	return db, repos
end

return BanchoAdapter
