local class = require("class")

---@class sea.MultiplayerClientRemoteValidation: sea.IClientRemoteContext
---@operator call: sea.MultiplayerClientRemoteValidation
local MultiplayerClientRemoteValidation = class()

---@param remote sea.MultiplayerClientRemote
function MultiplayerClientRemoteValidation:new(remote)
	self.remote = assert(remote)
end

---@param rooms sea.Room[]
function MultiplayerClientRemoteValidation:setRooms(rooms)
	self.remote:setRooms(rooms)
end

---@param room_users sea.RoomUser[]
function MultiplayerClientRemoteValidation:setRoomUsers(room_users)
	self.remote:setRoomUsers(room_users)
end

---@param users sea.User[]
function MultiplayerClientRemoteValidation:setUsers(users)
	self.remote:setUsers(users)
end

function MultiplayerClientRemoteValidation:startMatch()
	self.remote:startMatch()
end

function MultiplayerClientRemoteValidation:stopMatch()
	self.remote:stopMatch()
end

---@param msg string
function MultiplayerClientRemoteValidation:addMessage(msg)
	self.remote:addMessage(msg)
end

function MultiplayerClientRemoteValidation:syncRules()
	self.remote:syncRules()
end

function MultiplayerClientRemoteValidation:syncChart()
	self.remote:syncChart()
end

function MultiplayerClientRemoteValidation:syncReplayBase()
	self.remote:syncReplayBase()
end

return MultiplayerClientRemoteValidation
