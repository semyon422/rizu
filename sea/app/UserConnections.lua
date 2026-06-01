local class = require("class")
local TaskHandler = require("icc.TaskHandler")
local RemoteHandler = require("icc.RemoteHandler")
local BroadcastingPeer = require("icc.BroadcastingPeer")
local Remote = require("icc.Remote")
local ClientRemoteValidation = require("sea.app.remotes.ClientRemoteValidation")
local User = require("sea.access.User")
local InternalPeer = require("sea.app.InternalPeer")

local EMPTY_USER = User()

---@class sea.UserConnections
---@operator call: sea.UserConnections
---@field task_handler icc.TaskHandler
---@field remote_handler icc.RemoteHandler
---@field nats nats.INats NATS client connection
local UserConnections = class()

UserConnections.ttl = 90

---@param repo sea.UserConnectionsRepo
---@param users_repo sea.UsersRepo
function UserConnections:new(repo, users_repo)
	self.repo = repo
	self.users_repo = users_repo
end

---@param server_remote sea.ServerRemote
---@param whitelist icc.RemoteHandlerWhitelist
---@param client_whitelist icc.RemoteHandlerWhitelist
---@param nats nats.INats NATS client connection
function UserConnections:setup(server_remote, whitelist, client_whitelist, nats)
	self.remote_handler = RemoteHandler(server_remote, whitelist)
	self.task_handler = TaskHandler(self.remote_handler, "server")
	self.client_whitelist = client_whitelist
	self.nats = nats
end

---@param peer_id string
---@param user_id? integer
function UserConnections:onConnect(peer_id, user_id)
	self:heartbeat(peer_id, user_id)
end

---@param peer_id string
---@param user_id? integer
function UserConnections:onDisconnect(peer_id, user_id)
	self.repo:removeConnection(peer_id)
	if user_id then
		self.repo:setUserOffline(user_id)
	end
end

---@param user_id integer
function UserConnections:onUserConnect(user_id)
	self.repo:setUserOnline(user_id, self.ttl)
end

---@param user_id integer
function UserConnections:onUserDisconnect(user_id)
	self.repo:setUserOffline(user_id)
end

---@param peer_id string
---@param user_id? integer
function UserConnections:heartbeat(peer_id, user_id)
	self.repo:setConnection(peer_id, user_id, self.ttl)
	if user_id then
		self.repo:setUserOnline(user_id, self.ttl)
	end
end

function UserConnections:getOnlineCount()
	return self.repo:getGlobalCount()
end

---@param user_id integer
---@return boolean
function UserConnections:isUserOnline(user_id)
	return self.repo:isUserOnline(user_id)
end

---@private
---@param user_id integer|true|nil
---@return sea.User
function UserConnections:_getUser(user_id)
	if type(user_id) == "number" then
		return self.users_repo:getUser(user_id) or EMPTY_USER
	end
	return EMPTY_USER
end

---@param peer_id string
---@param peer sea.Peer
---@return sea.InternalPeer?
function UserConnections:getPeer(peer_id, peer)
	if not self.repo:hasConnection(peer_id) then
		return
	end
	local user_id = self.repo:getConnectionUser(peer_id)
	local user = self:_getUser(user_id)
	return InternalPeer(self.task_handler, peer.nc, peer.inbox, user, peer_id)
end

---@param peer sea.Peer
---@return sea.InternalPeer[]
function UserConnections:getPeers(peer)
	local peers = {}
	---@type {[integer|true]: sea.User}
	local users_cache = {}
	self.repo:forEachConnection(function(user_id, peer_id)
		local user = users_cache[user_id]
		if user == nil then
			user = self:_getUser(user_id)
			users_cache[user_id] = user
		end
		table.insert(peers, InternalPeer(self.task_handler, peer.nc, peer.inbox, user, peer_id))
	end)
	return peers
end

--- Get all currently connected non-anonymous users.
--- Collects unique user IDs from the shared dict and fetches in one query.
---@return sea.User[]
function UserConnections:getOnlineUsers()
	---@type {[integer]: true}
	local seen = {}
	---@type integer[]
	local ids = {}
	self.repo:forEachConnection(function(user_id)
		if type(user_id) ~= "number" then return end
		if seen[user_id] then return end
		seen[user_id] = true
		table.insert(ids, user_id)
	end)
	return self.users_repo:getUsersByIds(ids)
end

---@param client_remote sea.ClientRemoteValidation
---@return icc.TaskHandler
function UserConnections:createClientTaskHandler(client_remote)
	local handler = RemoteHandler(client_remote, self.client_whitelist)
	return TaskHandler(handler, "client-proxy")
end

--- No-return broadcast remote for all connected peers.
---@return sea.ClientRemoteValidation
function UserConnections:broadcastAll()
	local peer = BroadcastingPeer(self.nats, "icc.broadcast.all")
	return ClientRemoteValidation(-Remote(self.task_handler, peer))
end

--- No-return broadcast remote for a specific room.
---@param room_id integer
---@return sea.ClientRemoteValidation
function UserConnections:broadcastRoom(room_id)
	local peer = BroadcastingPeer(self.nats, "icc.broadcast.room." .. room_id)
	return ClientRemoteValidation(-Remote(self.task_handler, peer))
end

--- No-return broadcast remote for all sockets of a user.
---@param user_id integer
---@return sea.ClientRemoteValidation
function UserConnections:broadcastUser(user_id)
	local peer = BroadcastingPeer(self.nats, "icc.broadcast.user." .. user_id)
	return ClientRemoteValidation(-Remote(self.task_handler, peer))
end

return UserConnections
