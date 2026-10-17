local bcrypt = require("bcrypt")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local UsersRepo = require("sea.access.repos.UsersRepo")
local UserInsecure = require("sea.access.UserInsecure")
local BanchoCredential = require("sea.access.BanchoCredential")

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
	user.password = bcrypt.digest("password", 10)
	user.latest_activity = 0
	user.created_at = 0
	return ctx.users_repo:createUser(user)
end

---@param t testing.T
function test.bancho_credential_roundtrip(t)
	local ctx = create_ctx()
	local user = create_user(ctx)

	local credential = BanchoCredential()
	credential.user_id = user.id
	credential.password_md5_bcrypt = bcrypt.digest("md5-password", 10)
	credential.created_at = 10
	credential.updated_at = 10
	ctx.users_repo:createBanchoCredential(credential)

	local loaded = ctx.users_repo:getBanchoCredential(user.id)
	t:ne(loaded, nil)
	t:eq(loaded.user_id, user.id)
	t:eq(loaded.created_at, 10)

	loaded.updated_at = 20
	ctx.users_repo:updateBanchoCredential(loaded)

	local updated = ctx.users_repo:getBanchoCredential(user.id)
	t:eq(updated.updated_at, 20)

	ctx.users_repo:deleteBanchoCredential(user.id)
	t:eq(ctx.users_repo:getBanchoCredential(user.id), nil)
	ctx.db:close()
end

return test
