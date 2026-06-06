local bit = require("bit")
local md5 = require("md5")
local bcrypt = require("bcrypt")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local UsersRepo = require("sea.access.repos.UsersRepo")
local UserInsecure = require("sea.access.UserInsecure")
local UserRole = require("sea.access.UserRole")
local BanchoCredential = require("sea.access.BanchoCredential")
local BanchoUserSettings = require("sea.access.BanchoUserSettings")
local Privileges = require("bancho.constants.Privileges")
local SeaUserRepo = require("bancho.adapter.SeaUserRepo")

local test = {}

local function create_ctx()
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:remove()
	db:open()

	local users_repo = UsersRepo(db.models)
	local repo = SeaUserRepo(users_repo)

	return {
		db = db,
		users_repo = users_repo,
		repo = repo,
	}
end

local function create_user(ctx, name, email, password_hash)
	local user = UserInsecure()
	user.name = name
	user.email = email
	user.password = password_hash
	user.latest_activity = 0
	user.created_at = 0
	return ctx.users_repo:createUser(user)
end

---@param t testing.T
function test.find_user_maps_roles(t)
	local ctx = create_ctx()
	local user = create_user(ctx, "Alice", "alice@example.com", bcrypt.digest("pw", 10))

	local verified = UserRole("verified", 0)
	verified.user_id = user.id
	ctx.users_repo:createUserRole(verified)

	local donator = UserRole("donator", 0)
	donator.user_id = user.id
	ctx.users_repo:createUserRole(donator)

	local moderator = UserRole("moderator", 0)
	moderator.user_id = user.id
	ctx.users_repo:createUserRole(moderator)

	local bancho_user = ctx.repo:findUser(user.id)
	ctx.db:close()

	t:eq(bancho_user.name, "Alice")
	t:eq(bancho_user.email, "alice@example.com")
	t:eq(bancho_user.country_code, "xd")
	t:assert(bit.band(bancho_user.priv, Privileges.UNRESTRICTED) ~= 0)
	t:assert(bit.band(bancho_user.priv, Privileges.VERIFIED) ~= 0)
	t:assert(bit.band(bancho_user.priv, Privileges.SUPPORTER) ~= 0)
	t:assert(bit.band(bancho_user.priv, Privileges.MODERATOR) ~= 0)
end

---@param t testing.T
function test.find_user_by_name_and_password_uses_bancho_credentials(t)
	local ctx = create_ctx()
	local password_md5 = md5.sumhexa("password")
	local created_user = create_user(ctx, "BanchoUser", "bancho@example.com", bcrypt.digest("password", 10))

	local credential = BanchoCredential()
	credential.user_id = created_user.id
	credential.password_md5_bcrypt = bcrypt.digest(password_md5, 10)
	credential.created_at = 0
	credential.updated_at = 0
	ctx.users_repo:createBanchoCredential(credential)

	local user = ctx.repo:findUserByNameAndPassword("banchoUser", password_md5)
	local wrong = ctx.repo:findUserByNameAndPassword("banchoUser", "wrong")
	ctx.db:close()

	t:ne(user, nil)
	t:eq(user.name, "BanchoUser")
	t:eq(wrong, nil)
end

---@param t testing.T
function test.find_user_by_name_and_password_falls_back_to_legacy_bridge(t)
	local ctx = create_ctx()
	local password_md5 = md5.sumhexa("password")
	create_user(ctx, "LegacyUser", "legacy@example.com", bcrypt.digest(password_md5, 10))

	local user = ctx.repo:findUserByNameAndPassword("LegacyUser", password_md5)
	ctx.db:close()

	t:ne(user, nil)
	t:eq(user.name, "LegacyUser")
end

---@param t testing.T
function test.find_user_by_name_and_password_rejects_plaintext_hashes_without_bancho_credentials(t)
	local ctx = create_ctx()
	local password_md5 = md5.sumhexa("password")
	create_user(ctx, "SeaUser", "sea@example.com", bcrypt.digest("password", 10))

	local user = ctx.repo:findUserByNameAndPassword("SeaUser", password_md5)
	ctx.db:close()

	t:eq(user, nil)
end

---@param t testing.T
function test.update_session_prefs_persists_settings(t)
	local ctx = create_ctx()
	local user = create_user(ctx, "Alice", "alice@example.com", bcrypt.digest("pw", 10))

	ctx.repo:updateSessionPrefs(user.id, {
		utc_offset = 4,
		pm_private = true,
		stealth = true,
		away_msg = "afk",
		pres_filter = 2,
	})

	local settings = assert(ctx.users_repo:getBanchoUserSettings(user.id))
	local bancho_user = assert(ctx.repo:findUser(user.id))
	ctx.db:close()

	t:eq(settings.utc_offset, 4)
	t:eq(settings.pm_private, true)
	t:eq(settings.stealth, true)
	t:eq(settings.away_msg, "afk")
	t:eq(settings.pres_filter, 2)
	t:eq(bancho_user.utc_offset, 4)
	t:eq(bancho_user.pm_private, true)
	t:eq(bancho_user.away_msg, "afk")
	t:eq(bancho_user.pres_filter, 2)
end

---@param t testing.T
function test.find_user_uses_existing_settings(t)
	local ctx = create_ctx()
	local user = create_user(ctx, "Alice", "alice@example.com", bcrypt.digest("pw", 10))
	local settings = BanchoUserSettings()
	settings.user_id = user.id
	settings.utc_offset = 8
	settings.pm_private = true
	ctx.users_repo:createBanchoUserSettings(settings)

	local bancho_user = assert(ctx.repo:findUser(user.id))
	ctx.db:close()

	t:eq(bancho_user.utc_offset, 8)
	t:eq(bancho_user.pm_private, true)
end

---@param t testing.T
function test.partial_update_rejects_unsupported_fields(t)
	local ctx = create_ctx()
	local user = create_user(ctx, "Alice", "alice@example.com", bcrypt.digest("pw", 10))

	local ok = ctx.repo:partialUpdate(user.id, {priv = Privileges.ADMINISTRATOR})
	ctx.db:close()

	t:eq(ok, false)
end

return test
