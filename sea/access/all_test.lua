local bcrypt = require("bcrypt")
local md5 = require("md5")
local CustomAccess = require("sea.access.CustomAccess")
local IPasswordHasher = require("sea.access.IPasswordHasher")
local UsersRepo = require("sea.access.repos.UsersRepo")
local Users = require("sea.access.Users")
local User = require("sea.access.User")
local UserInsecure = require("sea.access.UserInsecure")
local UserUpdate = require("sea.access.UserUpdate")
local UserRole = require("sea.access.UserRole")
local FakeEmailSender = require("sea.access.FakeEmailSender")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")

local test = {}

local function create_test_ctx()
	local db = ServerSqliteDatabase(LjsqliteDatabase())

	db.path = ":memory:"

	db:remove()
	db:open()

	-- db.orm:debug(true)

	local models = db.models
	local users_repo = UsersRepo(models)

	local anon_user = User()

	return {
		db = db,
		users_repo = users_repo,
		anon_user = anon_user,
	}
end

---@param t testing.T
function test.owner_role_bypass(t)
	local access = {}
	function access:canUpdate(user, obj) return user.id == obj.owner_id end

	local time = 0
	local function clock() return time end

	local custom_access = CustomAccess(access, "qwe", clock)

	local user = User()
	user.id = 1

	local obj = {owner_id = 1}

	t:assert(access:canUpdate(user, obj))
	t:assert(custom_access:canUpdate(user, obj))

	obj.owner_id = 2

	t:assert(not access:canUpdate(user, obj))
	t:assert(not custom_access:canUpdate(user, obj))

	local user_role = UserRole("owner", 0)
	table.insert(user.user_roles, user_role)

	t:assert(not access:canUpdate(user, obj))
	t:assert(custom_access:canUpdate(user, obj))
end

---@param t testing.T
function test.has_role(t)
	local user = User()

	t:assert(not user:hasRole("owner", 0))

	local user_role = UserRole("admin", 0)
	table.insert(user.user_roles, user_role)

	t:assert(not user:hasRole("owner", 0))

	user_role = UserRole("owner", 0)
	table.insert(user.user_roles, user_role)

	t:assert(user:hasRole("owner", 0))
end

---@param t testing.T
function test.register_email_password(t)
	local ctx = create_test_ctx()

	local time = 0

	local users = Users(ctx.users_repo, IPasswordHasher())

	local user_values = UserInsecure()
	user_values.name = "user"
	user_values.email = "user@example.com"
	user_values.password = "password"

	local su, err = users:register(ctx.anon_user, "127.0.0.1", time, user_values)

	if not t:assert(su, err) then
		return
	end
	---@cast su -?

	t:eq(su.session.id, 1)
	t:eq(su.session.user_id, 1)
	t:eq(su.session.ip, nil)
	t:eq(su.user.email, nil)
	t:eq(su.user.password, nil)

	local bancho_credential = assert(ctx.users_repo:getBanchoCredential(su.user.id))
	t:assert(bcrypt.verify(md5.sumhexa("password"), bancho_credential.password_md5_bcrypt))

	---@type any
	local _

	_, err = users:register(ctx.anon_user, "127.0.0.1", time, user_values)
	t:eq(err, "rate_exceeded")

	_, err = users:register(ctx.anon_user, "127.0.0.2", time, user_values)
	t:eq(err, "email_taken")

	user_values.email = "user2@example.com"
	_, err = users:register(ctx.anon_user, "127.0.0.2", time, user_values)
	t:eq(err, "name_taken")

	user_values.name = "user2"
	_, err = users:register(ctx.anon_user, "127.0.0.2", time, user_values)
	t:assert(su, err)

	_, err = users:register(ctx.anon_user, "127.0.0.2", time, user_values)
	t:eq(err, "rate_exceeded")

	time = time + users.ip_register_delay

	_, err = users:register(ctx.anon_user, "127.0.0.2", time, user_values)
	t:eq(err, "email_taken")

	users.is_register_enabled = false

	_, err = users:register(ctx.anon_user, "127.0.0.2", time, user_values)
	t:eq(err, "disabled")
end

---@param t testing.T
function test.login_email_password(t)
	local ctx = create_test_ctx()

	local time = 0

	local users = Users(ctx.users_repo, IPasswordHasher())

	local user_values = UserInsecure()
	user_values.name = "user"
	user_values.email = "user@example.com"
	user_values.password = "password"

	local su, err = users:register(ctx.anon_user, "127.0.0.1", time, user_values)

	if not t:assert(su, err) then
		return
	end
	---@cast su -?

	t:eq(su.session.ip, nil)
	t:eq(su.user.id, 1)
	t:eq(su.user.email, nil)
	t:eq(su.user.password, nil)

	local user_values = UserInsecure()
	user_values.email = "user@example.com"
	user_values.password = "password"

	local su, err = users:login(ctx.anon_user, "127.0.0.1", time, user_values)

	if not t:assert(su, err) then
		return
	end
	---@cast su -?

	t:eq(su.session.user_id, su.user.id)
	t:eq(su.session.ip, nil)
	t:eq(su.user.email, nil)
	t:eq(su.user.password, nil)

	local bancho_credential = assert(ctx.users_repo:getBanchoCredential(su.user.id))
	t:assert(bcrypt.verify(md5.sumhexa("password"), bancho_credential.password_md5_bcrypt))

	---@type any
	local _

	user_values.email = "user2@example.com"
	_, err = users:login(ctx.anon_user, "127.0.0.1", time, user_values)
	t:eq(err, "invalid_credentials")

	user_values.email = "user@example.com"
	user_values.password = "password1"
	_, err = users:login(ctx.anon_user, "127.0.0.1", time, user_values)
	t:eq(err, "invalid_credentials")

	users.is_login_enabled = false

	user_values.password = "password"
	_, err = users:login(ctx.anon_user, "127.0.0.1", time, user_values)
	t:eq(err, "disabled")
end

---@param t testing.T
function test.login_populates_missing_bancho_credential(t)
	local ctx = create_test_ctx()
	local time = 0
	local users = Users(ctx.users_repo, IPasswordHasher())

	local user_values = UserInsecure()
	user_values.name = "user"
	user_values.email = "user@example.com"
	user_values.password = "password"
	user_values.latest_activity = time
	user_values.created_at = time

	local created_user = ctx.users_repo:createUser(user_values)
	t:eq(ctx.users_repo:getBanchoCredential(created_user.id), nil)

	local login_values = UserInsecure()
	login_values.email = "user@example.com"
	login_values.password = "password"

	local su, err = users:login(ctx.anon_user, "127.0.0.1", time, login_values)
	if not t:assert(su, err) then
		return
	end

	local bancho_credential = assert(ctx.users_repo:getBanchoCredential(created_user.id))
	t:assert(bcrypt.verify(md5.sumhexa("password"), bancho_credential.password_md5_bcrypt))
end

---@param t testing.T
function test.login_email_link(t)
	-- TODO
end

---@param t testing.T
function test.login_quick(t)
	-- TODO
	-- same IP, limit by time
end

---@param t testing.T
function test.register_oauth_osu(t)
	-- TODO
end

---@param t testing.T
function test.login_oauth_osu(t)
	-- TODO
end

---@param t testing.T
function test.ban(t)
	local ctx = create_test_ctx()

	local time = 0

	local users = Users(ctx.users_repo, IPasswordHasher())

	local user_values = UserInsecure()
	user_values.name = "user"
	user_values.email = "user@example.com"
	user_values.password = "password"

	local su, err = users:register(ctx.anon_user, "127.0.0.1", time, user_values)
	---@cast su -?

	local user_role = UserRole("owner", time)
	user_role:addTime(100, time)
	su.user.user_roles = {user_role}

	user_values.name = "user2"
	user_values.email = "user2@example.com"
	local su2, err = users:register(ctx.anon_user, "127.0.0.2", time, user_values)
	---@cast su2 -?

	local user, err = users:updateBanned(su.user, time, su2.user.id, true)

	if not t:assert(user, err) then
		return
	end
	---@cast user -?

	t:eq(user.id, su2.user.id)
	t:assert(user.is_banned)

	local _, err = users:updateBanned(su.user, 0, su.user.id, true)
	t:eq(err, "not allowed")

	local _, err = users:updateBanned(su.user, 0, 3, true)
	t:eq(err, "not found")
end

---@param t testing.T
function test.update(t)
	local ctx = create_test_ctx()

	local time = 0

	local users = Users(ctx.users_repo, IPasswordHasher())

	local user, err = users:updateUser(ctx.anon_user, UserUpdate(), time)
	t:eq(err, "not found")

	local user_values = UserUpdate()
	user_values.id = 999999
	user, err = users:updateUser(ctx.anon_user, user_values, time)
	t:eq(err, "not found")

	user_values = UserInsecure()
	user_values.name = "user"
	user_values.email = "user@example.com"
	user_values.password = "password"

	local su, err = users:register(ctx.anon_user, "127.0.0.1", time, user_values)
	---@cast su -?

	user_values = UserUpdate()
	user_values.id = su.user.id
	user, err = users:updateUser(ctx.anon_user, user_values, time)
	t:eq(err, "not allowed")

	user = users:getUser(su.user.id)
	user_values = UserUpdate()
	user_values.id = user.id
	user_values.description = "hello world"
	user_values.discord = "@user"

	user, err = users:updateUser(user, user_values, time)
	---@cast user -?
	t:eq(user.name, "user")
	t:eq(user.description, "hello world")
	t:eq(user.discord, "@user")

	user_values = UserUpdate()
	user_values.id = user.id
	user_values.name = "pro gamer"
	user, err = users:updateUser(user, user_values, time)
	---@cast user -?
	t:eq(user.name, "pro gamer")
	t:eq(user.discord, "@user")
	t:eq(user.description, "hello world")

	-------------

	user_values = UserInsecure()
	user_values.name = "hacker"
	user_values.email = "hacker@example.com"
	user_values.password = "password"
	su, err = users:register(ctx.anon_user, "127.0.0.2", time, user_values)
	---@cast su -?

	local player = users:getUser(user.id)
	local hacker = users:getUser(su.user.id)
	user_values = UserUpdate()
	user_values.id = player.id

	user, err = users:updateUser(hacker, user_values, time)
	t:eq(err, "not allowed")
end

---@param t testing.T
function test.update_email(t)
	local ctx = create_test_ctx()

	local time = 0

	local users = Users(ctx.users_repo, IPasswordHasher())

	local user, err = users:updateEmail(ctx.anon_user, "aaa", "email@example.com", time)
	t:eq(err, "not allowed")

	local user_values = UserInsecure()
	user_values.name = "user"
	user_values.email = "user@example.com"
	user_values.password = "password"

	local su, err = users:register(ctx.anon_user, "127.0.0.1", time, user_values)
	---@cast su -?
	user = users:getUser(su.user.id)

	local _, err = users:updateEmail(user, "wrong password", "new_email@example.com", time)
	t:eq(err, "invalid credentials")

	local _, err = users:updateEmail(user, "password", "new_email@example.com", time)
	user = users.users_repo:getUserInsecure(user.id)
	---@cast user -?
	t:eq(user.email, "new_email@example.com")
end

---@param t testing.T
function test.update_password(t)
	local ctx = create_test_ctx()

	local time = 0

	local users = Users(ctx.users_repo, IPasswordHasher())

	local user, err = users:updatePassword(ctx.anon_user, "password", "new_password", time)
	t:eq(err, "not allowed")

	local user_values = UserInsecure()
	user_values.name = "user"
	user_values.email = "user@example.com"
	user_values.password = "password"

	local su, err = users:register(ctx.anon_user, "127.0.0.1", time, user_values)
	---@cast su -?
	user = users:getUser(su.user.id)
	---@cast user -?

	local _, err = users:updatePassword(user, "wrong password", "new_password", time)
	t:eq(err, "invalid credentials")

	local _, err = users:updatePassword(user, "password", "new_password", time)
	local _user = users.users_repo:getUserInsecure(user.id)
	---@cast _user -?
	t:eq(_user.password, "new_password")

	local bancho_credential = assert(ctx.users_repo:getBanchoCredential(user.id))
	t:assert(bcrypt.verify(md5.sumhexa("new_password"), bancho_credential.password_md5_bcrypt))
end

---@param t testing.T
function test.reset_password(t)
	local ctx = create_test_ctx()

	local email_sender = FakeEmailSender()
	local users = Users(ctx.users_repo, IPasswordHasher(), email_sender)

	local email = "user@example.com"
	local email_2 = "user2@example.com"

	local user_values = UserInsecure()
	user_values.name = "user"
	user_values.email = email
	user_values.password = "password"

	local su, err = users:register(ctx.anon_user, "127.0.0.1", 0, user_values)
	---@cast su -?

	local user = su.user

	local code, err = users:createAndSendPasswordResetAuthCode("127.0.0.1", email_2, 0, 10, 2)
	t:eq(err, "user not found")

	code, err = users:createAndSendPasswordResetAuthCode("127.0.0.1", email_2, 0, 10, 2)
	t:eq(err, "user not found")

	t:tdeq(email_sender.emails, {})

	code, err = users:createAndSendPasswordResetAuthCode("127.0.0.1", email, 0, 10, 2)
	if not t:assert(code, err) then
		return
	end
	---@cast code -?

	t:tdeq(email_sender.emails, {"user@example.com: password reset code: " .. code})

	local _, err = users:updatePasswordUsingCode(0, "qwe", "new_password")
	t:eq(err, "code not found")

	local _, err = users:updatePasswordUsingCode(20, code, "new_password")
	t:eq(err, "code expired")

	local ok, err = users:updatePasswordUsingCode(0, code, "new_password")
	if not t:assert(ok, err) then
		return
	end

	user = assert(ctx.users_repo:getUserInsecure(1))
	t:eq(user.password, "new_password")

	local bancho_credential = assert(ctx.users_repo:getBanchoCredential(user.id))
	t:assert(bcrypt.verify(md5.sumhexa("new_password"), bancho_credential.password_md5_bcrypt))

	local _, err = users:updatePasswordUsingCode(0, code, "new_password")
	t:eq(err, "code used")

	local _, err = users:updatePasswordUsingCode(20, code, "new_password")
	t:eq(err, "code used")

	_, err = users:createAndSendPasswordResetAuthCode("127.0.0.1", email, 0, 10, 2)
	t:eq(err, "rate limit")

	code, err = users:createAndSendPasswordResetAuthCode("127.0.0.1", email, 2, 10, 2)
	t:assert(code, err)
end

return test
