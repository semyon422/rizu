local Events = require("rizu.api.Events")

--[[
The player's account and the connection to the server.

	local online = ui.api.online
	local name = online:getUsername() or "Guest"
	online:on("account_changed", function() ... end)
	online:login(email, password, function(ok, err) ... end)
]]

---@alias rizu.api.Online.Event
---| "account_changed" # The player logged in or out, or the connection went up or down. No arguments.
---| "online_count_changed" # getOnlineCount() has a new answer. No arguments.

---@class rizu.api.Online : rizu.api.Events
---@operator call: rizu.api.Online
---@field on fun(self: rizu.api.Online, event: rizu.api.Online.Event, f: function): fun()
---@field private client rizu.OnlineClient
---@field private avatars rizu.online.AvatarCache
---@field private auth rizu.AuthManager
local Online = Events + {}

---@param game sphere.GameController
function Online:new(game)
	Events.new(self)
	local client = game.online_client
	self.client = client
	self.avatars = game.avatar_cache
	self.auth = game.onlineModel.authManager
	client:onChanged(function(event)
		if event.type == "online_count_changed" then
			self:emit("online_count_changed")
		elseif event.type == "user_changed" or event.type == "connection_changed"
			or event.type == "authentication_resolved"
		then
			self:emit("account_changed")
		end
	end)
end

---@return boolean
function Online:isConnected() return self.client:isConnected() end

---@return string? name nil while offline or not logged in
function Online:getUsername()
	local user = self.client:getUser()
	if self.client:isConnected() and user and type(user.name) == "string" and user.name ~= "" then
		return user.name
	end
end

---@return string? url The logged in player's avatar, for getAvatar().
function Online:getAvatarUrl()
	local user = self.client:getUser()
	return user and user.avatar
end

---@return integer? count Players online. nil while offline.
function Online:getOnlineCount()
	return self.client:isConnected() and self.client:getOnlineCount() or nil
end

---Any player's avatar. The first call for a url starts the download and returns nil; keep asking
---every frame and the image shows up when it is ready.
---@param url string?
---@return love.Image? image
function Online:getAvatar(url) return self.avatars:get(url) end

---Logs in with the account's email and password. The player stays logged in after a restart.
---f gets true when it worked, otherwise false and the server's reason. "account_changed" follows.
---@param email string
---@param password string
---@param f fun(ok: boolean, err: string?)
function Online:login(email, password, f)
	local observer
	observer = self.client:onChanged(function(event)
		if event.type == "login_succeeded" then
			self.client:offChanged(observer)
			f(true)
		elseif event.type == "login_failed" then
			self.client:offChanged(observer)
			f(false, event.error)
		end
	end)
	self.auth:login(email, password)
end

function Online:logout() self.auth:logout() end

return Online
