local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local UsersRepo = require("sea.access.repos.UsersRepo")
local UserInsecure = require("sea.access.UserInsecure")
local BanchoUserSettings = require("sea.access.BanchoUserSettings")

local test = {}

local function create_ctx()
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:remove()
	db:open()

	local users_repo = UsersRepo(db.models)
	return {
		db = db,
		users_repo = users_repo,
	}
end

local function create_user(ctx)
	local user = UserInsecure()
	user.name = "user"
	user.email = "user@example.com"
	user.password = "password"
	user.latest_activity = 0
	user.created_at = 0
	return ctx.users_repo:createUser(user)
end

---@param t testing.T
function test.bancho_user_settings_roundtrip(t)
	local ctx = create_ctx()
	local user = create_user(ctx)

	local settings = BanchoUserSettings()
	settings.user_id = user.id
	settings.utc_offset = 3
	settings.pm_private = true
	settings.stealth = true
	settings.away_msg = "away"
	settings.pres_filter = 2
	ctx.users_repo:createBanchoUserSettings(settings)

	local loaded = ctx.users_repo:getBanchoUserSettings(user.id)
	t:ne(loaded, nil)
	t:eq(loaded.utc_offset, 3)
	t:eq(loaded.pm_private, true)
	t:eq(loaded.away_msg, "away")

	loaded.pres_filter = 1
	ctx.users_repo:updateBanchoUserSettings(loaded)

	local updated = ctx.users_repo:getBanchoUserSettings(user.id)
	t:eq(updated.pres_filter, 1)

	ctx.users_repo:deleteBanchoUserSettings(user.id)
	t:eq(ctx.users_repo:getBanchoUserSettings(user.id), nil)
	ctx.db:close()
end

return test
