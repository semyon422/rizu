local class = require("class")
local thread = require("thread")
local pprint = require("pprint")

---@class rizu.AuthManager
---@operator call: rizu.AuthManager
---@field configModel sphere.ConfigModel
local AuthManager = class()

---@param sea_client rizu.SeaClient
---@param configModel sphere.ConfigModel
function AuthManager:new(sea_client, configModel)
	self.sea_client = sea_client
	self.configModel = configModel
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
AuthManager.checkUser = thread.coro(AuthManager.checkUserAsync)

function AuthManager:checkSessionAsync()
	print("check session")

	local server_remote = self.sea_client.remote
	local config = self.configModel.configs.online
	local urls = self.configModel.configs.urls
	---@type {[string]: string}
	local tokens = config.tokens

	local token = tokens[urls.websocket]
	if not token then
		print("no token for current server")
		return
	end

	local ok = server_remote.auth:loginByToken(token)
	if not ok then
		print("invalid token")
		return
	end

	config.session = server_remote:getSession()
	print("session = " .. pprint.dump(config.session))

	self:checkUserAsync()
end
AuthManager.checkSession = thread.coro(AuthManager.checkSessionAsync)

---@param email string
---@param password string
function AuthManager:loginAsync(email, password)
	print("login")

	local sea_client = self.sea_client
	local server_remote = sea_client.remote
	local config = self.configModel.configs.online
	local urls = self.configModel.configs.urls

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
	tokens[urls.websocket] = ret.token

	self:checkSessionAsync()
end
AuthManager.login = thread.coro(AuthManager.loginAsync)

function AuthManager:logoutAsync()
	print("logout")

	local sea_client = self.sea_client
	local server_remote = sea_client.remote
	local config = self.configModel.configs.online
	local urls = self.configModel.configs.urls

	pcall(server_remote.auth.logout, server_remote.auth)

	config.session = {}
	config.user = {}
	---@type {[string]: string?}
	local tokens = config.tokens
	tokens[urls.websocket] = nil

	sea_client.client:setUser()
end
AuthManager.logout = thread.coro(AuthManager.logoutAsync)

return AuthManager
