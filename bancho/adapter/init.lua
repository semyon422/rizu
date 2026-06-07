local BanchoDatabase = require("bancho.db.BanchoDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local Repos = require("bancho.db.repos")

local SeaUserRepo = require("bancho.adapter.SeaUserRepo")
local SeaFriendsRepo = require("bancho.adapter.SeaFriendsRepo")
local SeaFavouritesRepo = require("bancho.adapter.SeaFavouritesRepo")
local SeaStatsRepo = require("bancho.adapter.SeaStatsRepo")
local SeaBeatmapRepo = require("bancho.adapter.SeaBeatmapRepo")
local SeaScoreRepo = require("bancho.adapter.SeaScoreRepo")
local SeaReplayRepo = require("bancho.adapter.SeaReplayRepo")

local BanchoAdapter = {}

BanchoAdapter.SeaUserRepo = SeaUserRepo
BanchoAdapter.SeaFriendsRepo = SeaFriendsRepo
BanchoAdapter.SeaFavouritesRepo = SeaFavouritesRepo
BanchoAdapter.SeaStatsRepo = SeaStatsRepo
BanchoAdapter.SeaBeatmapRepo = SeaBeatmapRepo
BanchoAdapter.SeaScoreRepo = SeaScoreRepo
BanchoAdapter.SeaReplayRepo = SeaReplayRepo

---@param server bancho.server.BanchoServer
---@param path string?
---@param users_repo? sea.UsersRepo
---@param leaderboards_repo? sea.LeaderboardsRepo
---@param charts_repo? sea.ChartsRepo
---@param osu_repo? sea.OsuRepo
---@param osu_beatmaps? sea.OsuBeatmaps
---@param charts_storage? sea.IKeyValueStorage
---@param chartplay_submission? sea.ChartplaySubmission
---@param replays_storage? sea.IKeyValueStorage
---@return bancho.BanchoDatabase
---@return bancho.Repos
function BanchoAdapter.setupLegacyDatabase(server, path, users_repo, leaderboards_repo, charts_repo, osu_repo, osu_beatmaps, charts_storage, chartplay_submission, replays_storage)
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
	local beatmap_repo = charts_repo and osu_repo and SeaBeatmapRepo(charts_repo, osu_repo, osu_beatmaps, charts_storage) or repos.beatmap_repo
	local score_repo = users_repo and charts_repo and chartplay_submission and charts_storage and SeaScoreRepo(users_repo, charts_repo, chartplay_submission, charts_storage, beatmap_repo) or repos.score_repo
	local replay_repo = users_repo and charts_repo and replays_storage and SeaReplayRepo(charts_repo, users_repo, replays_storage) or repos.replay_repo

	server.db = db
	server:setRepos(
		user_repo,
		score_repo,
		beatmap_repo,
		friends_repo,
		favourites_repo,
		stats_repo,
		replay_repo
	)

	return db, repos
end

return BanchoAdapter
