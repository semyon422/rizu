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

---@class bancho.adapter.Repos
---@field user_repo bancho.adapter.SeaUserRepo
---@field score_repo bancho.adapter.SeaScoreRepo
---@field beatmap_repo bancho.adapter.SeaBeatmapRepo
---@field friends_repo bancho.adapter.SeaFriendsRepo
---@field favourites_repo bancho.adapter.SeaFavouritesRepo
---@field stats_repo bancho.adapter.SeaStatsRepo
---@field replay_repo bancho.adapter.SeaReplayRepo

---@param users_repo sea.UsersRepo
---@param leaderboards_repo sea.LeaderboardsRepo
---@param charts_repo sea.ChartsRepo
---@param osu_repo sea.OsuRepo
---@param osu_beatmaps sea.OsuBeatmaps
---@param charts_storage sea.IKeyValueStorage
---@param chartplay_submission sea.ChartplaySubmission
---@param replays_storage sea.IKeyValueStorage
---@return bancho.adapter.Repos
function BanchoAdapter.createSeaRepos(users_repo, leaderboards_repo, charts_repo, osu_repo, osu_beatmaps, charts_storage, chartplay_submission, replays_storage)
	local beatmap_repo = SeaBeatmapRepo(charts_repo, osu_repo, osu_beatmaps, charts_storage)
	return {
		user_repo = SeaUserRepo(users_repo),
		score_repo = SeaScoreRepo(users_repo, charts_repo, chartplay_submission, charts_storage, beatmap_repo),
		beatmap_repo = beatmap_repo,
		friends_repo = SeaFriendsRepo(users_repo),
		favourites_repo = SeaFavouritesRepo(users_repo),
		stats_repo = SeaStatsRepo(users_repo, leaderboards_repo),
		replay_repo = SeaReplayRepo(charts_repo, users_repo, replays_storage),
	}
end

---@param server bancho.server.BanchoServer
---@param users_repo sea.UsersRepo
---@param leaderboards_repo sea.LeaderboardsRepo
---@param charts_repo sea.ChartsRepo
---@param osu_repo sea.OsuRepo
---@param osu_beatmaps sea.OsuBeatmaps
---@param charts_storage sea.IKeyValueStorage
---@param chartplay_submission sea.ChartplaySubmission
---@param replays_storage sea.IKeyValueStorage
---@return bancho.adapter.Repos
function BanchoAdapter.setupSeaRepos(server, users_repo, leaderboards_repo, charts_repo, osu_repo, osu_beatmaps, charts_storage, chartplay_submission, replays_storage)
	local repos = BanchoAdapter.createSeaRepos(
		users_repo,
		leaderboards_repo,
		charts_repo,
		osu_repo,
		osu_beatmaps,
		charts_storage,
		chartplay_submission,
		replays_storage
	)

	server:setRepos(
		repos.user_repo,
		repos.score_repo,
		repos.beatmap_repo,
		repos.friends_repo,
		repos.favourites_repo,
		repos.stats_repo,
		repos.replay_repo
	)

	return repos
end

return BanchoAdapter
