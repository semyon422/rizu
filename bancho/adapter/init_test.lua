local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local UsersRepo = require("sea.access.repos.UsersRepo")
local BanchoAdapter = require("bancho.adapter")
local BanchoServer = require("bancho.server.BanchoServer")

local test = {}

---@param t testing.T
function test.setup_legacy_database(t)
	local server = BanchoServer()
	local path = "tmp_bancho_adapter_test.db"

	os.remove(path)
	BanchoAdapter.setupLegacyDatabase(server, path)

	t:ne(server.db, nil)
	t:ne(server.user_repo, nil)
	t:ne(server.score_repo, nil)
	t:ne(server.beatmap_repo, nil)
	t:ne(server.friends_repo, nil)
	t:ne(server.favourites_repo, nil)
	t:ne(server.stats_repo, nil)
	t:ne(server.replay_repo, nil)

	server:closeDatabase()
	os.remove(path)
end

---@param t testing.T
function test.setup_legacy_database_with_sea_user_repo(t)
	local sea_db = ServerSqliteDatabase(LjsqliteDatabase())
	sea_db.path = ":memory:"
	sea_db:remove()
	sea_db:open()

	local users_repo = UsersRepo(sea_db.models)
	local server = BanchoServer()
	local path = "tmp_bancho_adapter_test.db"

	os.remove(path)
	BanchoAdapter.setupLegacyDatabase(server, path, users_repo)

	t:eq(getmetatable(server.user_repo), BanchoAdapter.SeaUserRepo)
	t:ne(server.score_repo, nil)

	server:closeDatabase()
	sea_db:close()
	os.remove(path)
end

return test
