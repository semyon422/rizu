local class = require("class")
local thread = require("thread")
local pprint = require("pprint")

---@class rizu.AuthManager
---@operator call: rizu.AuthManager
---@field configModel sphere.ConfigModel
local AuthManager = class()

---@param config_model sphere.ConfigModel
---@return string url
local function getServerUrl(config_model)
	local configs = config_model.configs
	local selected_url = configs.online.url
	for _, server in ipairs(configs.urls.servers) do
		if server.url == selected_url then
			return selected_url
		end
	end
	error("selected online server does not exist: " .. selected_url)
end

---@param sea_client rizu.SeaClient
---@param operation string
---@param f fun(...: any)
---@return function
local function backgroundAuthCall(sea_client, operation, f)
	return thread.coro(function(...)
		local ok, err = xpcall(f, debug.traceback, ...)
		if ok then
			return
		end
		print(("online %s failed: %s"):format(operation, tostring(err)))
		sea_client:closeWebsocket(operation .. " failed")
	end)
end

---@param sea_client rizu.SeaClient
---@param configModel sphere.ConfigModel
function AuthManager:new(sea_client, configModel)
	self.sea_client = sea_client
	self.configModel = configModel
	self.checkUser = backgroundAuthCall(sea_client, "user refresh", function(_)
		self:checkUserAsync()
	end)
	self.checkSession = backgroundAuthCall(sea_client, "session check", function(_)
		self:checkSessionAsync()
	end)
	self.login = backgroundAuthCall(sea_client, "login", function(_, email, password)
		self:loginAsync(email, password)
	end)
	self.logout = backgroundAuthCall(sea_client, "logout", function(_)
		self:logoutAsync()
	end)
end

function AuthManager:checkUserAsync()
	print("check user")
	local sea_client = self.sea_client
	local user = sea_client.remote:getUser()
	sea_client.client:setUser(user)
	self.configModel.configs.online.user = user
	print("user = " .. pprint.dump(user))

	sea_client.remote:printAll("Hello from " .. (user and user.name or "unknown"))

	local nums = sea_client.remote:getRandomNumbersFromAllClients()
	print("random numbers from all clients:")
	pprint(nums)
end

function AuthManager:checkSessionAsync()
	print("check session")

	local server_remote = self.sea_client.remote
	local config = self.configModel.configs.online
	local server_url = getServerUrl(self.configModel)
	---@type {[string]: string}
	local tokens = config.tokens

	local token = tokens[server_url]
	if not token then
		print("no token for current server")
		return
	end

	local ok, err = server_remote.auth:loginByToken(token)
	if not ok then
		print("invalid token", err)
		return
	end

	config.session = server_remote:getSession()
	print("session = " .. pprint.dump(config.session))

	self:checkUserAsync()
end

---@param email string
---@param password string
function AuthManager:loginAsync(email, password)
	print("login")

	local sea_client = self.sea_client
	local server_remote = sea_client.remote
	local config = self.configModel.configs.online
	local server_url = getServerUrl(self.configModel)

	---@type {session: sea.Session, user: sea.User, token: string}?
	local ret
	---@type string?
	local err
	ret, err = server_remote.auth:login(email, password)
	if not ret then
		print(err)
		return
	end

	config.session = ret.session
	config.user = ret.user
	---@type {[string]: string}
	local tokens = config.tokens
	tokens[server_url] = ret.token
	self.configModel:write("online")

	self:checkSessionAsync()
end

function AuthManager:logoutAsync()
	print("logout")

	local sea_client = self.sea_client
	local server_remote = sea_client.remote
	local config = self.configModel.configs.online
	local server_url = getServerUrl(self.configModel)

	pcall(server_remote.auth.logout, server_remote.auth)

	config.session = {}
	config.user = {}
	---@type {[string]: string?}
	local tokens = config.tokens
	tokens[server_url] = nil
	self.configModel:write("online")

	sea_client.client:setUser()
end

return AuthManager
