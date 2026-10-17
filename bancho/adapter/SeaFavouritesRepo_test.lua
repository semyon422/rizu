local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local UsersRepo = require("sea.access.repos.UsersRepo")
local UserInsecure = require("sea.access.UserInsecure")
local SeaFavouritesRepo = require("bancho.adapter.SeaFavouritesRepo")

local test = {}

local function create_ctx()
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:remove()
	db:open()

	local users_repo = UsersRepo(db.models)
	return {
		db = db,
		repo = SeaFavouritesRepo(users_repo),
		users_repo = users_repo,
	}
end

local function create_user(ctx, name, email)
	local user = UserInsecure()
	user.name = name
	user.email = email
	user.password = "password"
	user.latest_activity = 0
	user.created_at = 0
	return ctx.users_repo:createUser(user)
end

---@param t testing.T
function test.crud(t)
	local ctx = create_ctx()
	local user = create_user(ctx, "u1", "u1@example.com")

	t:eq(ctx.repo:addFavourite(user.id, 100), true)
	t:eq(ctx.repo:addFavourite(user.id, 200), true)
	t:tdeq(ctx.repo:getFavourites(user.id), {100, 200})
	t:eq(ctx.repo:removeFavourite(user.id, 100), true)
	t:tdeq(ctx.repo:getFavourites(user.id), {200})
	ctx.db:close()
end

return test
