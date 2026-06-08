local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local SharedMemory = require("web.nginx.SharedMemory")
local FakeFilesystem = require("fs.FakeFilesystem")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local Repos = require("sea.app.Repos")
local Domain = require("sea.app.Domain")
local BanchoAdapter = require("bancho.adapter")
local BanchoServer = require("bancho.server.BanchoServer")

local test = {}

---@param t testing.T
function test.setup_sea_repos(t)
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:remove()
	db:open()

	local shared_memory = SharedMemory()
	local repos = Repos(db.models, shared_memory)
	local domain = Domain(repos, {
		osu_api = {client_id = "x", client_secret = "y", redirect_uri = "z"},
	}, FakeFilesystem())
	local server = BanchoServer(shared_memory)

	BanchoAdapter.setupSeaRepos(
		server,
		repos.users_repo,
		repos.leaderboards_repo,
		repos.charts_repo,
		repos.osu_repo,
		domain.osu_beatmaps,
		domain.charts_storage,
		domain.chartplay_submission,
		domain.replays_storage
	)

	t:eq(getmetatable(server.user_repo), BanchoAdapter.SeaUserRepo)
	t:eq(getmetatable(server.friends_repo), BanchoAdapter.SeaFriendsRepo)
	t:eq(getmetatable(server.favourites_repo), BanchoAdapter.SeaFavouritesRepo)
	t:eq(getmetatable(server.stats_repo), BanchoAdapter.SeaStatsRepo)
	t:eq(getmetatable(server.beatmap_repo), BanchoAdapter.SeaBeatmapRepo)
	t:eq(getmetatable(server.score_repo), BanchoAdapter.SeaScoreRepo)
	t:eq(getmetatable(server.replay_repo), BanchoAdapter.SeaReplayRepo)

	db:close()
end

return test
