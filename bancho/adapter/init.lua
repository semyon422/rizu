local BanchoDatabase = require("bancho.db.BanchoDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local Repos = require("bancho.db.repos")

local SeaUserRepo = require("bancho.adapter.SeaUserRepo")

local BanchoAdapter = {}

BanchoAdapter.SeaUserRepo = SeaUserRepo

---@param server bancho.server.BanchoServer
---@param path string?
---@param users_repo? sea.UsersRepo
---@return bancho.BanchoDatabase
---@return bancho.Repos
function BanchoAdapter.setupLegacyDatabase(server, path, users_repo)
	local db = BanchoDatabase(LjsqliteDatabase())
	if path then
		db.path = path
	end
	db:open()

	local repos = Repos(db.models)
	local user_repo = users_repo and SeaUserRepo(users_repo) or repos.user_repo

	server.db = db
	server:setRepos(
		user_repo,
		repos.score_repo,
		repos.beatmap_repo,
		repos.friends_repo,
		repos.favourites_repo,
		repos.stats_repo,
		repos.replay_repo
	)

	return db, repos
end

return BanchoAdapter
