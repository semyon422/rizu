local class = require("class")
local Room = require("sea.multi.Room")
local RoomUpdate = require("sea.multi.RoomUpdate")
local RoomUser = require("sea.multi.RoomUser")
local MultiplayerAccess = require("sea.multi.access.MultiplayerAccess")

---@class sea.Multiplayer
---@operator call: sea.Multiplayer
local Multiplayer = class()

---@param multiplayer_repo sea.MultiplayerRepo
---@param user_connections sea.UserConnections
function Multiplayer:new(multiplayer_repo, user_connections)
	self.multiplayer_repo = multiplayer_repo
	self.user_connections = user_connections
	self.multiplayer_access = MultiplayerAccess()
end

---@param peer sea.Peer
function Multiplayer:getPeers(peer)
	return self.user_connections:getPeers(peer)
end

---@param peer sea.Peer
function Multiplayer:connected(peer)
	self:pushUsers(peer)
	peer.remote_no_return.multiplayer:setRooms(self:getRooms())
end

---@param peer sea.Peer
function Multiplayer:disconnected(peer)
	self:leaveRoom(peer)
end

---@param peer sea.Peer
---@return sea.User[]
function Multiplayer:getUsers(peer)
	---@type sea.User[]
	local users = {}
	for _, p in ipairs(self:getPeers(peer)) do
		if not p.user:isAnon() then
			table.insert(users, p.user)
		end
	end
	table.sort(users, function(a, b)
		return a.id < b.id
	end)
	return users
end

---@param user_id integer
---@param peer sea.Peer
---@return sea.InternalPeer?
function Multiplayer:getPeerByUserId(user_id, peer)
	local peer_id = self.user_connections.repo:getPeerIdByUserId(user_id)
	if not peer_id then
		return
	end
	return self.user_connections:getPeer(peer_id, peer)
end

---@param room_id integer
---@param peer sea.Peer
function Multiplayer:iterRoomPeers(room_id, peer)
	local room_users = self.multiplayer_repo:getRoomUsers(room_id)

	---@type {[integer]: true}
	local user_ids = {}
	for _, room_user in ipairs(room_users) do
		user_ids[room_user.user_id] = true
	end

	---@type sea.Peer[]
	local peers = {}
	for _, p in ipairs(self:getPeers(peer)) do
		if user_ids[p.user.id] then
			table.insert(peers, p)
		end
	end

	return ipairs(peers)
end

---@return sea.Room[]
function Multiplayer:getRooms()
	local rooms = self.multiplayer_repo:getRooms()
	for _, room in ipairs(rooms) do
		room.password = nil
	end
	return rooms
end

---@param id integer
---@return sea.Room?
function Multiplayer:getRoom(id)
	return self.multiplayer_repo:getRoom(id)
end

---@param peer sea.Peer
function Multiplayer:pushUsers(peer)
	local users = self:getUsers(peer)
	for _, p in ipairs(self:getPeers(peer)) do
		p.remote_no_return.multiplayer:setUsers(users)
	end
end

---@param peer sea.Peer
function Multiplayer:pushRooms(peer)
	local rooms = self:getRooms()
	for _, p in ipairs(self:getPeers(peer)) do
		p.remote_no_return.multiplayer:setRooms(rooms)
	end
end

---@param room_id integer
---@param peer sea.Peer
function Multiplayer:pushRoomUsers(room_id, peer)
	local room_users = self.multiplayer_repo:getRoomUsers(room_id)
	for _, p in self:iterRoomPeers(room_id, peer) do
		p.remote_no_return.multiplayer:setRoomUsers(room_users)
	end
end

---@param room_id integer
---@param room sea.Room|sea.RoomUpdate
---@param peer sea.Peer
function Multiplayer:syncRoomParts(room_id, room, peer)
	for _, p in self:iterRoomPeers(room_id, peer) do
		if room.rules then
			p.remote_no_return.multiplayer:syncRules()
		end
		if room.chartmeta_key then
			p.remote_no_return.multiplayer:syncChart()
		end
		if room.replay_base then
			p.remote_no_return.multiplayer:syncReplayBase()
		end
	end
end

---@param peer sea.Peer
---@param room_values sea.Room
---@return integer?
---@return string?
function Multiplayer:createRoom(peer, room_values)
	local user = peer.user
	if not self.multiplayer_access:canCreateRoom(user) then
		return nil, "not allowed"
	end

	room_values.host_user_id = user.id

	local room = self.multiplayer_repo:createRoom(room_values)
	self:pushRooms(peer)

	self:joinRoom(peer, room.id, room.password)

	return room.id
end

---@param peer sea.Peer
---@param room_id integer
---@param room_values sea.RoomUpdate
---@return true?
---@return string?
function Multiplayer:updateRoom(peer, room_id, room_values)
	local user = peer.user
	local room = self.multiplayer_repo:getRoom(room_id)
	if not room then
		return nil, "not found"
	end

	if not self.multiplayer_access:canUpdateRoom(user, room) then
		return nil, "not allowed"
	end

	room_values.id = room_id

	self.multiplayer_repo:updateRoom(room_values)
	self:pushRooms(peer)

	self:syncRoomParts(room_id, room_values, peer)

	return true
end

---@param peer sea.Peer
---@param room_id integer
---@param password string
---@return true?
---@return string?
function Multiplayer:joinRoom(peer, room_id, password)
	local user = peer.user
	local room = self.multiplayer_repo:getRoom(room_id)
	if not room then
		return nil, "not found"
	end

	if not self.multiplayer_access:canJoinRoom(user, room) then
		return nil, "not allowed"
	end

	local room_user = self.multiplayer_repo:getRoomUserByUserId(user.id)
	if room_user then
		return nil, "is in a room"
	end

	if room.password ~= password then
		return nil, "invalid password"
	end

	room_user = RoomUser(room.id, user.id)
	room_user = self.multiplayer_repo:createRoomUser(room_user)

	self:pushRoomUsers(room_id, peer)
	self:syncRoomParts(room_id, room, peer)

	return true
end

---@param peer sea.Peer
---@param room_id integer
---@param target_user_id integer
---@return true?
---@return string?
function Multiplayer:kickUser(peer, room_id, target_user_id)
	local user = peer.user
	local room = self.multiplayer_repo:getRoom(room_id)
	if not room then
		return nil, "not found"
	end

	if not self.multiplayer_access:canKickUser(user, room, target_user_id) then
		return nil, "not allowed"
	end

	local room_user = self.multiplayer_repo:deleteRoomUser(room_id, target_user_id)
	if not room_user then
		return nil, "not found"
	end

	local room_users = self.multiplayer_repo:getRoomUsers(room_id)

	if #room_users == 0 then
		self.multiplayer_repo:deleteRoom(room_id)
		self:pushRooms(peer)
	else
		if room.host_user_id == target_user_id then
			room.host_user_id = room_users[1].user_id
			self.multiplayer_repo:updateRoom(room)
			self:pushRooms(peer)
		end
		self:pushRoomUsers(room_id, peer)
	end

	local target_peer = self:getPeerByUserId(target_user_id, peer)
	if target_peer then
		target_peer.remote_no_return.multiplayer:setRoomUsers({})
	end

	return true
end

---@param user sea.User
---@return integer?
function Multiplayer:getRoomId(user)
	if user:isAnon() then
		return
	end
	local room_user = self.multiplayer_repo:getRoomUserByUserId(user.id)
	if not room_user then
		return
	end
	return room_user.room_id
end

---@param peer sea.Peer
---@param user? sea.User
---@return true?
---@return string?
function Multiplayer:leaveRoom(peer, user)
	user = user or peer.user
	if user:isAnon() then
		return
	end

	local room_id = self:getRoomId(user)
	if not room_id then
		return nil, "is not in a room"
	end

	return self:kickUser(peer, room_id, user.id)
end

---@return sea.Room?
function Multiplayer:getCurrentRoom(user)
	local id = self:getRoomId(user)
	if id then
		return self:getRoom(id)
	end
end

---@param peer sea.Peer
---@param room_id integer
---@param msg string
function Multiplayer:sendMessage(peer, room_id, msg)
	local user = peer.user
	msg = ("%s: %s"):format(user.name, msg)

	for _, p in self:iterRoomPeers(room_id, peer) do
		p.remote_no_return.multiplayer:addMessage(msg)
	end
end

---@param peer sea.Peer
---@param msg string
function Multiplayer:sendLocalMessage(peer, msg)
	local room_id = self:getRoomId(peer.user)
	if not room_id then
		return
	end
	self:sendMessage(peer, room_id, msg)
end

---@param peer sea.Peer
---@param room_values sea.RoomUpdate
---@return boolean?
---@return string?
function Multiplayer:updateLocalRoom(peer, room_values)
	local room_id = self:getRoomId(peer.user)
	if not room_id then
		return
	end
	return self:updateRoom(peer, room_id, room_values)
end

---@param peer sea.Peer
---@param target_user_id integer
function Multiplayer:kickLocalUser(peer, target_user_id)
	local room_id = self:getRoomId(peer.user)
	if not room_id then
		return
	end
	self:kickUser(peer, room_id, target_user_id)
end

---@param peer sea.Peer
function Multiplayer:switchReady(peer)
	local user = peer.user
	local room_user = self.multiplayer_repo:getRoomUserByUserId(user.id)
	if not room_user then
		return
	end

	room_user.is_ready = not room_user.is_ready
	self.multiplayer_repo:updateRoomUser(room_user)

	self:pushRoomUsers(room_user.room_id, peer)
end

---@param peer sea.Peer
---@param found boolean
function Multiplayer:setChartFound(peer, found)
	local user = peer.user
	local room_user = self.multiplayer_repo:getRoomUserByUserId(user.id)
	if not room_user then
		return
	end

	room_user.chart_found = found
	self.multiplayer_repo:updateRoomUser(room_user)

	self:pushRoomUsers(room_user.room_id, peer)
end

---@param peer sea.Peer
---@param chartplay_computed sea.ChartplayComputed
function Multiplayer:setChartplayComputed(peer, chartplay_computed)
	local user = peer.user
	local room_user = self.multiplayer_repo:getRoomUserByUserId(user.id)
	if not room_user then
		return
	end

	room_user.chartplay_computed = chartplay_computed
	self.multiplayer_repo:updateRoomUser(room_user)

	self:pushRoomUsers(room_user.room_id, peer)
end

---@param peer sea.Peer
---@param is_playing boolean
function Multiplayer:setPlaying(peer, is_playing)
	local user = peer.user
	local room_user = self.multiplayer_repo:getRoomUserByUserId(user.id)
	if not room_user then
		return
	end

	room_user.is_playing = is_playing
	self.multiplayer_repo:updateRoomUser(room_user)

	self:pushRoomUsers(room_user.room_id, peer)
end

---@param peer sea.Peer
function Multiplayer:startLocalMatch(peer)
	local room_id = self:getRoomId(peer.user)
	if not room_id then
		return
	end

	for _, p in self:iterRoomPeers(room_id, peer) do
		p.remote_no_return.multiplayer:startMatch()
	end
end

---@param peer sea.Peer
function Multiplayer:stopLocalMatch(peer)
	local room_id = self:getRoomId(peer.user)
	if not room_id then
		return
	end

	for _, p in self:iterRoomPeers(room_id, peer) do
		p.remote_no_return.multiplayer:stopMatch()
	end
end

return Multiplayer
