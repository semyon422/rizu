local class = require("class")

---@class sea.MultiplayerServerRemote: sea.IServerRemoteContext
---@operator call: sea.MultiplayerServerRemote
local MultiplayerServerRemote = class()

---@param multiplayer sea.Multiplayer
function MultiplayerServerRemote:new(multiplayer)
	self.multiplayer = multiplayer
end

---@param ... any
function MultiplayerServerRemote:print(...)
	print(...)
end

---@return sea.Room[]
function MultiplayerServerRemote:getRooms()
	return self.multiplayer:getRooms()
end

---@return sea.User[]
function MultiplayerServerRemote:getUsers()
	return self.multiplayer:getUsers()
end

---@return sea.User
function MultiplayerServerRemote:getUser()
	return self.user
end

---@return integer?
function MultiplayerServerRemote:getRoomId()
	return self.multiplayer:getRoomId(self.user)
end

---@param room_values sea.Room
---@return integer?
---@return string?
function MultiplayerServerRemote:createRoom(room_values)
	return self.multiplayer:createRoom(self.peer, room_values)
end

---@param room_id integer
---@param password string
---@return boolean?
---@return string?
function MultiplayerServerRemote:joinRoom(room_id, password)
	return self.multiplayer:joinRoom(self.peer, room_id, password)
end

---@return boolean?
---@return string?
function MultiplayerServerRemote:leaveRoom()
	return self.multiplayer:leaveRoom(self.peer)
end

---@return sea.Room?
function MultiplayerServerRemote:getCurrentRoom()
	return self.multiplayer:getCurrentRoom(self.user)
end

---@param chartplay_computed sea.ChartplayComputed
function MultiplayerServerRemote:setChartplayComputed(chartplay_computed)
	self.multiplayer:setChartplayComputed(self.peer, chartplay_computed)
end

function MultiplayerServerRemote:switchReady()
	self.multiplayer:switchReady(self.peer)
end

---@param found boolean
function MultiplayerServerRemote:setChartFound(found)
	self.multiplayer:setChartFound(self.peer, found)
	return true
end

---@param is_playing boolean
function MultiplayerServerRemote:setPlaying(is_playing)
	self.multiplayer:setPlaying(self.peer, is_playing)
end

---@param msg string
function MultiplayerServerRemote:sendMessage(msg)
	self.multiplayer:sendLocalMessage(self.peer, msg)
end

---@param room_values sea.RoomUpdate
---@return boolean?
---@return string?
function MultiplayerServerRemote:updateRoom(room_values)
	return self.multiplayer:updateLocalRoom(self.peer, room_values)
end

---@param user_id integer
function MultiplayerServerRemote:kickUser(user_id)
	self.multiplayer:kickLocalUser(self.peer, user_id)
end

function MultiplayerServerRemote:startMatch()
	self.multiplayer:startLocalMatch(self.peer)
end

function MultiplayerServerRemote:stopMatch()
	self.multiplayer:stopLocalMatch(self.peer)
end

return MultiplayerServerRemote
