local class = require("class")
local SubmissionServerRemote = require("sea.chart.remotes.SubmissionServerRemote")
local AuthServerRemote = require("sea.access.remotes.AuthServerRemote")
local LeaderboardsServerRemote = require("sea.leaderboards.remotes.LeaderboardsServerRemote")
local DifftablesServerRemote = require("sea.difftables.remotes.DifftablesServerRemote")
local MultiplayerServerRemote = require("sea.app.remotes.MultiplayerServerRemote")

---@class sea.ServerRemote: sea.IServerRemoteContext
---@field multiplayer sea.MultiplayerServerRemote
---@operator call: sea.ServerRemote
local ServerRemote = class()

---@param domain sea.Domain
---@param sessions web.Sessions
function ServerRemote:new(domain, sessions)
	self.auth = AuthServerRemote(domain.users, sessions, domain.user_connections, function(peer, old_user)
		domain:onAuth(peer, old_user)
	end)
	self.submission = SubmissionServerRemote(domain.chartplay_submission, domain.chartplays)
	self.leaderboards = LeaderboardsServerRemote(domain.leaderboards)
	self.difftables = DifftablesServerRemote(domain.difftables)
	self.multiplayer = MultiplayerServerRemote(domain.multiplayer)
	self.user_connections = domain.user_connections
	self.domain = domain
end

---@return sea.User
function ServerRemote:getUser()
	return self.user
end

---@return sea.Session
function ServerRemote:getSession()
	return self.session
end

---@param msg string
---@return string
function ServerRemote:ping(msg)
	self:heartbeat()
	return msg .. "world" .. self.user.id
end

function ServerRemote:heartbeat()
	self.user_connections:heartbeat(self.peer_id, self.user.id)
end

---@param msg string
function ServerRemote:printAll(msg)
	self.domain:printAll(msg)
end

---@return number[]
function ServerRemote:getRandomNumbersFromAllClients()
	return self.domain:getRandomNumbersFromAllClients(self.peer)
end

return ServerRemote
