local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local UsersRepo = require("sea.access.repos.UsersRepo")
local UserInsecure = require("sea.access.UserInsecure")

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
function test.user_friends_roundtrip(t)
	local ctx = create_ctx()
	local user = create_user(ctx, "u1", "u1@example.com")
	local friend1 = create_user(ctx, "u2", "u2@example.com")
	local friend2 = create_user(ctx, "u3", "u3@example.com")

	t:eq(ctx.users_repo:addUserFriend(user.id, friend1.id), true)
	t:eq(ctx.users_repo:addUserFriend(user.id, friend2.id), true)
	t:eq(ctx.users_repo:isUserFriend(user.id, friend1.id), true)
	t:tdeq(ctx.users_repo:getUserFriends(user.id), {friend1.id, friend2.id})
	t:eq(ctx.users_repo:removeUserFriend(user.id, friend1.id), true)
	t:tdeq(ctx.users_repo:getUserFriends(user.id), {friend2.id})
	ctx.db:close()
end

---@param t testing.T
function test.user_osu_favourites_roundtrip(t)
	local ctx = create_ctx()
	local user = create_user(ctx, "u1", "u1@example.com")

	t:eq(ctx.users_repo:addUserOsuFavourite(user.id, 100), true)
	t:eq(ctx.users_repo:addUserOsuFavourite(user.id, 200), true)
	t:tdeq(ctx.users_repo:getUserOsuFavourites(user.id), {100, 200})
	t:eq(ctx.users_repo:removeUserOsuFavourite(user.id, 100), true)
	t:tdeq(ctx.users_repo:getUserOsuFavourites(user.id), {200})
	ctx.db:close()
end

return test
