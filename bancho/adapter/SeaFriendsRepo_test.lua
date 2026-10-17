local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local UsersRepo = require("sea.access.repos.UsersRepo")
local UserInsecure = require("sea.access.UserInsecure")
local SeaFriendsRepo = require("bancho.adapter.SeaFriendsRepo")

local test = {}

local function create_ctx()
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:remove()
	db:open()

	local users_repo = UsersRepo(db.models)
	return {
		db = db,
		repo = SeaFriendsRepo(users_repo),
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
	local friend = create_user(ctx, "u2", "u2@example.com")

	t:eq(ctx.repo:addFriend(user.id, friend.id), true)
	t:eq(ctx.repo:isFriend(user.id, friend.id), true)
	t:tdeq(ctx.repo:getFriends(user.id), {friend.id})
	t:eq(ctx.repo:removeFriend(user.id, friend.id), true)
	t:eq(ctx.repo:isFriend(user.id, friend.id), false)
	ctx.db:close()
end

return test
