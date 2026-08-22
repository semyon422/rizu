local AuthManager = require("rizu.online.AuthManager")

local test = {}

local function makeManager()
	local closed_with
	local users = {}
	local sea_client = {
		client = {
			setUser = function(_, user) table.insert(users, user) end,
		},
		remote = {},
		closeWebsocket = function(_, err) closed_with = err end,
	}
	local config_model = {
		configs = {
			online = {url = "ws://test", tokens = {}, user = {}},
			urls = {servers = {{name = "Test", url = "ws://test"}}},
		},
	}
	local manager = AuthManager(sea_client, config_model) ---@diagnostic disable-line
	return manager, sea_client, config_model, function() return closed_with, users end
end

---@param t testing.T
function test.check_user_runs_diagnostic_rpcs(t)
	local manager, sea_client, config_model, getValues = makeManager()
	local calls = {}
	sea_client.remote = {
		getUser = function()
			table.insert(calls, "getUser")
			return {id = 7, name = "player"}
		end,
		printAll = function() table.insert(calls, "printAll") end,
		getRandomNumbersFromAllClients = function() table.insert(calls, "random") end,
	}

	manager:checkUserAsync()
	local _, users = getValues()
	t:tdeq(calls, {"getUser", "printAll", "random"})
	t:eq(users[1].id, 7)
	t:eq(config_model.configs.online.user.id, 7)
end

---@param t testing.T
function test.background_timeout_disconnects_without_throwing(t)
	local manager, sea_client, _, getValues = makeManager()
	sea_client.remote = {
		getUser = function() error("timeout") end,
	}

	local ok, co = pcall(manager.checkUser, manager)
	t:eq(ok, true)
	t:eq(coroutine.status(co), "dead")
	local closed_with = getValues()
	t:eq(closed_with, "user refresh failed")
end

return test
