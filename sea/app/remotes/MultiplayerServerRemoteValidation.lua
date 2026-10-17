local class = require("class")
local types = require("sea.shared.types")
local valid = require("valid")
local Room = require("sea.multi.Room")
local RoomUpdate = require("sea.multi.RoomUpdate")
local User = require("sea.access.User")

---@class sea.MultiplayerServerRemoteValidation: sea.MultiplayerServerRemote
---@operator call: sea.MultiplayerServerRemoteValidation
local MultiplayerServerRemoteValidation = class()

---@param remote sea.MultiplayerServerRemote
function MultiplayerServerRemoteValidation:new(remote)
	self.remote = remote
end

---@param ... any
function MultiplayerServerRemoteValidation:print(...)
	return self.remote:print(...)
end

---@return sea.Room[]
function MultiplayerServerRemoteValidation:getRooms()
	local rooms = self.remote:getRooms()
	assert(type(rooms) == "table")
	for _, room in ipairs(rooms) do
		setmetatable(room, Room)
	end
	return rooms
end

---@return sea.User[]
function MultiplayerServerRemoteValidation:getUsers()
	local users = self.remote:getUsers()
	assert(type(users) == "table")
	for _, user in ipairs(users) do
		setmetatable(user, User)
	end
	return users
end

---@return sea.User
function MultiplayerServerRemoteValidation:getUser()
	local user = self.remote:getUser()
	assert(type(user) == "table")
	return setmetatable(user, User)
end

---@return integer?
function MultiplayerServerRemoteValidation:getRoomId()
	local res = self.remote:getRoomId()
	assert(res == nil or type(res) == "number")
	return res
end

---@param room_values sea.Room
---@return integer?
---@return string?
function MultiplayerServerRemoteValidation:createRoom(room_values)
	assert(type(room_values) == "table")
	return self.remote:createRoom(room_values)
end

---@param room_id integer
---@param password string
---@return boolean?
---@return string?
function MultiplayerServerRemoteValidation:joinRoom(room_id, password)
	assert(type(room_id) == "number")
	assert(type(password) == "string")
	return self.remote:joinRoom(room_id, password)
end

---@return boolean?
---@return string?
function MultiplayerServerRemoteValidation:leaveRoom()
	return self.remote:leaveRoom()
end

---@return sea.Room?
function MultiplayerServerRemoteValidation:getCurrentRoom()
	local room = self.remote:getCurrentRoom()
	if room then
		assert(type(room) == "table")
		setmetatable(room, Room)
	end
	return room
end

---@param chartplay_computed sea.ChartplayComputed
function MultiplayerServerRemoteValidation:setChartplayComputed(chartplay_computed)
	assert(type(chartplay_computed) == "table")
	return self.remote:setChartplayComputed(chartplay_computed)
end

function MultiplayerServerRemoteValidation:switchReady()
	return self.remote:switchReady()
end

---@param found boolean
function MultiplayerServerRemoteValidation:setChartFound(found)
	if not types.boolean(found) then
		return nil, "invalid found"
	end
	return self.remote:setChartFound(found)
end

---@param is_playing boolean
function MultiplayerServerRemoteValidation:setPlaying(is_playing)
	assert(type(is_playing) == "boolean")
	return self.remote:setPlaying(is_playing)
end

---@param msg string
function MultiplayerServerRemoteValidation:sendMessage(msg)
	assert(type(msg) == "string")
	return self.remote:sendMessage(msg)
end

---@param room_values sea.RoomUpdate
---@return boolean?
---@return string?
function MultiplayerServerRemoteValidation:updateRoom(room_values)
	assert(type(room_values) == "table")
	local ok, err = valid.format(RoomUpdate.validate(room_values))
	if not ok then
		return nil, "validate room update: " .. err
	end
	setmetatable(room_values, RoomUpdate)

	return self.remote:updateRoom(room_values)
end

---@param user_id integer
function MultiplayerServerRemoteValidation:kickUser(user_id)
	assert(type(user_id) == "number")
	return self.remote:kickUser(user_id)
end

function MultiplayerServerRemoteValidation:startMatch()
	return self.remote:startMatch()
end

function MultiplayerServerRemoteValidation:stopMatch()
	return self.remote:stopMatch()
end

return MultiplayerServerRemoteValidation
