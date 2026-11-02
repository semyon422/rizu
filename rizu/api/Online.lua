local Events = require("rizu.api.Events")
local icc_co = require("icc.co")

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
---| "online_players_changed" # getOnlinePlayers() has a new answer. No arguments.
---| "recent_scores_changed" # getRecentScores() has a new answer. No arguments.
---| "chat_message" # A message arrived in the chat. Arguments: sea.chat.ChatMessage.
---| "player_joined" # Another player came online while the game was connected. Arguments: rizu.api.Online.Player.

---@class rizu.api.Online.Player
---@field name string
---@field avatar_url string? for getAvatar()
---@field role "admin"|"donator"? admin also means the owner
---@field chartplays_count integer
---@field play_time number seconds

---@class rizu.api.Online.RecentScore
---@field player_name string
---@field title string
---@field difficulty string the chart's difficulty name, may be empty
---@field accuracy number 0..1

---@class rizu.api.Online : rizu.api.Events
---@operator call: rizu.api.Online
---@field on fun(self: rizu.api.Online, event: rizu.api.Online.Event, f: function): fun()
---@field private client rizu.OnlineClient
---@field private multiplayer sea.MultiplayerClient
---@field private chat sea.chat.ChatClient
---@field private avatars rizu.online.AvatarCache
---@field private auth rizu.AuthManager
---@field private arrivals {[string]: integer} order in which the online players came, by name, latest highest
---@field private arrival_count integer
---@field private has_arrivals boolean false until the first list after connecting
local Online = Events + {}

---Plain tables from the server, so the role is read here instead of with sea.User:hasRole().
---@param user sea.User
---@return "admin"|"donator"?
local function getRole(user)
	local time = os.time()
	local donator = false
	for _, user_role in ipairs(user.user_roles or {}) do
		if not (user_role.expires_at and user_role.expires_at < time) then
			if user_role.role == "owner" or user_role.role == "admin" then return "admin" end
			donator = donator or user_role.role == "donator"
		end
	end
	return donator and "donator" or nil
end

---@param user sea.User
---@return rizu.api.Online.Player
local function toPlayer(user)
	return {
		name = user.name,
		avatar_url = user.avatar,
		role = getRole(user),
		chartplays_count = user.chartplays_count or 0,
		play_time = user.play_time or 0,
	}
end

---Notes when each player on the server's list came online. The server sends no times, so the order
---comes from the lists. In the first one after connecting, which is oldest account first, the newest
---account counts as the latest.
---@param self rizu.api.Online
---@return rizu.api.Online.Player[] joined the players new to the list, except the first list and this player
local function updateArrivals(self)
	local joined = {} ---@type rizu.api.Online.Player[]
	local own_name = self:getUsername()
	local listed = {} ---@type {[string]: true}
	for _, user in ipairs(self.multiplayer.users) do
		local name = user.name
		listed[name] = true
		if not self.arrivals[name] then
			self.arrival_count = self.arrival_count + 1
			self.arrivals[name] = self.arrival_count
			if self.has_arrivals and name ~= own_name then
				table.insert(joined, toPlayer(user))
			end
		end
	end
	for name in pairs(self.arrivals) do
		if not listed[name] then self.arrivals[name] = nil end
	end
	self.has_arrivals = true
	return joined
end

---@param game sphere.GameController
function Online:new(game)
	Events.new(self)
	local client = game.online_client
	self.client = client
	self.avatars = game.avatar_cache
	self.auth = game.onlineModel.authManager
	self.arrivals = {}
	self.arrival_count = 0
	self.has_arrivals = false
	client:onChanged(function(event)
		if event.type == "online_count_changed" then
			self:emit("online_count_changed")
		elseif event.type == "recent_scores_changed" then
			self:emit("recent_scores_changed")
		elseif event.type == "connection_changed" then
			self.arrivals = {}
			self.has_arrivals = false
			self:emit("account_changed")
		elseif event.type == "user_changed"
			or event.type == "authentication_resolved"
		then
			self:emit("account_changed")
		end
	end)
	self.chat = game.chat_client
	self.chat:onChanged(function(event)
		self:emit("chat_message", event.message)
	end)
	self.multiplayer = game.multiplayer_client
	-- The server pushes the whole list whenever a player connects, logs in or leaves.
	self.multiplayer:onChanged(function(event)
		if event.type == "users_changed" then
			local joined = updateArrivals(self)
			self:emit("online_players_changed")
			for _, player in ipairs(joined) do
				self:emit("player_joined", player)
			end
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

---False while the server has not said yet who the player is: see isAuthenticationResolved().
---@return boolean
function Online:isLoggedIn()
	local user = self.client:getUser()
	return user ~= nil and user.id ~= nil
end

---True once the game knows whether the player is logged in, so a login button does not flash on startup.
---@return boolean
function Online:isAuthenticationResolved() return self.client:isAuthenticationResolved() end

---@return string? url The logged in player's avatar, for getAvatar().
function Online:getAvatarUrl()
	local user = self.client:getUser()
	return user and user.avatar
end

---@return integer? count Players online. nil while offline.
function Online:getOnlineCount()
	return self.client:isConnected() and self.client:getOnlineCount() or nil
end

---@return rizu.api.Online.Player[] players Logged in players on the server, the latest to come online first. Empty while offline.
function Online:getOnlinePlayers()
	local players = {} ---@type rizu.api.Online.Player[]
	if not self.client:isConnected() then return players end
	local users = {} ---@type sea.User[]
	for i, user in ipairs(self.multiplayer.users) do users[i] = user end
	local arrivals = self.arrivals
	table.sort(users, function(a, b) return (arrivals[a.name] or 0) > (arrivals[b.name] or 0) end)
	for i, user in ipairs(users) do players[i] = toPlayer(user) end
	return players
end

---@return rizu.api.Online.RecentScore[] scores The newest scores submitted by any player, newest first. Empty while offline.
function Online:getRecentScores()
	local scores = {} ---@type rizu.api.Online.RecentScore[]
	if not self.client:isConnected() then return scores end
	for i, score in ipairs(self.client.recent_scores) do
		scores[i] = {
			player_name = score.user_name,
			title = score.title,
			difficulty = score.chart_name,
			accuracy = score.accuracy,
		}
	end
	return scores
end

---Any player's avatar. The first call for a url starts the download and returns nil; keep asking
---every frame and the image shows up when it is ready.
---@param url string?
---@return love.Image? image
function Online:getAvatar(url) return self.avatars:get(url) end

-- TODO: weak spot. f is called by the first login result the client reports, so a login started
-- somewhere else (a command) at the same time would end it. AuthManager.login should take a callback.
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

---@return sea.chat.ChatMessage[]
function Online:getChatMessages() return self.chat.messages end

---Sends to the global chat. f gets true when the server took it, otherwise false and the reason,
---such as being offline. The message itself comes back as "chat_message".
---@param text string
---@param f fun(ok: boolean, err: string?)
function Online:sendChatMessage(text, f)
	icc_co.pwrap(function() return self.chat:sendMessageAsync(text) end, function(ok, sent, err)
		if not ok then
			-- A thrown error, such as "aqua/coext.lua:66: [client] not connected": drop the position.
			f(false, (tostring(sent):gsub("^[^:]+:%d+: ", "")))
			return
		end
		f(sent == true, err)
	end)()
end

function Online:logout() self.auth:logout() end

return Online
