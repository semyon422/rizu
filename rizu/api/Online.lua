local Events = require("rizu.api.Events")

--[[
The player's account and the connection to the server.

	local online = ui.api.online
	local name = online:getUsername() or "Guest"
	online:on("account_changed", function() ... end)
]]

---@alias rizu.api.Online.Event
---| "account_changed" # The player logged in or out, or the connection went up or down. No arguments.
---| "online_count_changed" # getOnlineCount() has a new answer. No arguments.

---@class rizu.api.Online : rizu.api.Events
---@operator call: rizu.api.Online
---@field on fun(self: rizu.api.Online, event: rizu.api.Online.Event, f: function): fun()
---@field private client rizu.OnlineClient
---@field private avatars rizu.online.AvatarCache
local Online = Events + {}

---@param client rizu.OnlineClient
---@param avatars rizu.online.AvatarCache
function Online:new(client, avatars)
	Events.new(self)
	self.client = client
	self.avatars = avatars
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

return Online
