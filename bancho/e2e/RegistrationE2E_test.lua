local E2EContext = require("bancho.e2e.E2EContext")
local TestLib = require("bancho.e2e.TestLib")
local md5 = require("md5")

local test = {}

---@param t testing.T
function test.register_and_login(t)
	local ctx = E2EContext()
	local account_resource = ctx:createAccountResource()
	local username = "NewPlayer"
	local email = "newplayer@test.com"
	local password = "testpass123"

	local req, res, read_soc = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = username,
		["user[user_email]"] = email,
		["user[password]"] = password,
		check = "0",
	})
	account_resource:registerAccount(req, res)
	t:eq(ctx:readHttpResponse(read_soc), "ok")

	local repos = ctx.bancho_repos
	local user = repos.user_repo:findUserByName(username)
	t:ne(user, nil)
	t:eq(user.name, username)
	t:eq(user.email, email)

	for mode = 0, 3 do
		local stats = repos.stats_repo:getStats(user.id, mode)
		t:ne(stats, nil)
		t:eq(stats.plays, 0)
		t:eq(stats.tscore, 0)
	end

	local client = TestLib.createClient(ctx, username, md5.sumhexa(password))
	local result = client:login()
	t:eq(result.success, true)
	t:eq(result.user_id, user.id)

	ctx:close()
end

---@param t testing.T
function test.register_duplicate_username(t)
	local ctx = E2EContext()
	local account_resource = ctx:createAccountResource()
	local password = "testpass123"

	local req1, res1, read_soc1 = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "DupPlayer",
		["user[user_email]"] = "dup1@test.com",
		["user[password]"] = password,
		check = "0",
	})
	account_resource:registerAccount(req1, res1)
	t:eq(ctx:readHttpResponse(read_soc1), "ok")

	local req2, res2, read_soc2 = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "DupPlayer",
		["user[user_email]"] = "dup2@test.com",
		["user[password]"] = password,
		check = "0",
	})
	account_resource:registerAccount(req2, res2)
	local body = ctx:readHttpResponse(read_soc2)
	t:ne(body, "ok")
	t:ne(body:find("Username already taken"), nil)

	ctx:close()
end

---@param t testing.T
function test.register_duplicate_email(t)
	local ctx = E2EContext()
	local account_resource = ctx:createAccountResource()
	local password = "testpass123"

	local req1, res1, read_soc1 = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "player1",
		["user[user_email]"] = "same@test.com",
		["user[password]"] = password,
		check = "0",
	})
	account_resource:registerAccount(req1, res1)
	t:eq(ctx:readHttpResponse(read_soc1), "ok")

	local req2, res2, read_soc2 = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "player2",
		["user[user_email]"] = "same@test.com",
		["user[password]"] = password,
		check = "0",
	})
	account_resource:registerAccount(req2, res2)
	local body = ctx:readHttpResponse(read_soc2)
	t:ne(body, "ok")
	t:ne(body:find("Email already taken"), nil)

	ctx:close()
end

---@param t testing.T
function test.register_short_username(t)
	local ctx = E2EContext()
	local account_resource = ctx:createAccountResource()

	local req, res, read_soc = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "A",
		["user[user_email]"] = "a@test.com",
		["user[password]"] = "testpass123",
		check = "0",
	})
	account_resource:registerAccount(req, res)
	local body = ctx:readHttpResponse(read_soc)
	t:ne(body, "ok")
	t:ne(body:find("2%-15 characters"), nil)

	ctx:close()
end

---@param t testing.T
function test.register_short_password(t)
	local ctx = E2EContext()
	local account_resource = ctx:createAccountResource()

	local req, res, read_soc = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "TestUser",
		["user[user_email]"] = "test@test.com",
		["user[password]"] = "short",
		check = "0",
	})
	account_resource:registerAccount(req, res)
	local body = ctx:readHttpResponse(read_soc)
	t:ne(body, "ok")
	t:ne(body:find("8%-32 characters"), nil)

	ctx:close()
end

---@param t testing.T
function test.register_invalid_email(t)
	local ctx = E2EContext()
	local account_resource = ctx:createAccountResource()

	local req, res, read_soc = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "TestUser",
		["user[user_email]"] = "notanemail",
		["user[password]"] = "testpass123",
		check = "0",
	})
	account_resource:registerAccount(req, res)
	local body = ctx:readHttpResponse(read_soc)
	t:ne(body, "ok")
	t:ne(body:find("Invalid email"), nil)

	ctx:close()
end

---@param t testing.T
function test.register_username_space_and_underscore(t)
	local ctx = E2EContext()
	local account_resource = ctx:createAccountResource()

	local req, res, read_soc = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "Bad_Name Here",
		["user[user_email]"] = "test@test.com",
		["user[password]"] = "testpass123",
		check = "0",
	})
	account_resource:registerAccount(req, res)
	local body = ctx:readHttpResponse(read_soc)
	t:ne(body, "ok")
	t:ne(body:find("but not both"), nil)

	ctx:close()
end

---@param t testing.T
function test.register_low_unique_password(t)
	local ctx = E2EContext()
	local account_resource = ctx:createAccountResource()

	local req, res, read_soc = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "TestUser",
		["user[user_email]"] = "test@test.com",
		["user[password]"] = "aaaa1111",
		check = "0",
	})
	account_resource:registerAccount(req, res)
	local body = ctx:readHttpResponse(read_soc)
	t:ne(body, "ok")
	t:ne(body:find("more than 3 unique characters"), nil)

	ctx:close()
end

---@param t testing.T
function test.register_check_only(t)
	local ctx = E2EContext()
	local account_resource = ctx:createAccountResource()
	local repos = ctx.bancho_repos

	local req, res, read_soc = ctx:createMultipartRequest("POST", "/users", {
		["user[username]"] = "DryRunUser",
		["user[user_email]"] = "dryrun@test.com",
		["user[password]"] = "testpass123",
		check = "1",
	})
	account_resource:registerAccount(req, res)
	t:eq(ctx:readHttpResponse(read_soc), "ok")
	t:eq(repos.user_repo:findUserByName("DryRunUser"), nil)

	ctx:close()
end

return test
