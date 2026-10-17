local class = require("class")
local stbl = require("stbl")

---@class sea.MultiplayerRepo
---@operator call: sea.MultiplayerRepo
local MultiplayerRepo = class()

---@param rooms_dict web.ISharedDict
---@param room_users_dict web.ISharedDict
function MultiplayerRepo:new(rooms_dict, room_users_dict)
	self.rooms_dict = rooms_dict
	self.room_users_dict = room_users_dict
end

---@return { [integer]: any }
function MultiplayerRepo:getRooms()
	local rooms = {}
	local keys = self.rooms_dict:get_keys(0)
	for _, key in ipairs(keys) do
		if key ~= "id" then
			local room_json = self.rooms_dict:get(key)
			if room_json then
				table.insert(rooms, stbl.decode(room_json))
			end
		end
	end
	return rooms
end

---@param id integer
---@return any?
function MultiplayerRepo:getRoom(id)
	local room_json = self.rooms_dict:get(tostring(id))
	if room_json then
		return stbl.decode(room_json)
	end
	return nil
end

---@param room table
---@return table
function MultiplayerRepo:createRoom(room)
	local id = self.rooms_dict:incr("id", 1, 0)
	room.id = id
	self.rooms_dict:set(tostring(id), stbl.encode(room))
	return room
end

---@param room table
---@return table
function MultiplayerRepo:updateRoom(room)
	self.rooms_dict:set(tostring(room.id), stbl.encode(room))
	return room
end

---@param id integer
function MultiplayerRepo:deleteRoom(id)
	self.rooms_dict:delete(tostring(id))
end

---@param room_id integer
---@param user_id integer
---@return any?
function MultiplayerRepo:getRoomUser(room_id, user_id)
	local room_user_json = self.room_users_dict:get(tostring(user_id))
	if room_user_json then
		local room_user = stbl.decode(room_user_json)
		if room_user.room_id == room_id then
			return room_user
		end
	end
	return nil
end

---@param room_id integer
---@return any[]
function MultiplayerRepo:getRoomUsers(room_id)
	local room_users = {}
	local keys = self.room_users_dict:get_keys(0)
	for _, key in ipairs(keys) do
		local room_user_json = self.room_users_dict:get(key)
		if room_user_json then
			local room_user = stbl.decode(room_user_json)
			if room_user.room_id == room_id then
				table.insert(room_users, room_user)
			end
		end
	end
	return room_users
end

---@param user_id integer
---@return any?
function MultiplayerRepo:getRoomUserByUserId(user_id)
	local room_user_json = self.room_users_dict:get(tostring(user_id))
	if room_user_json then
		return stbl.decode(room_user_json)
	end
	return nil
end

---@param room_user table
---@return table
function MultiplayerRepo:createRoomUser(room_user)
	self.room_users_dict:set(tostring(room_user.user_id), stbl.encode(room_user))
	return room_user
end

---@param room_user table
---@return table
function MultiplayerRepo:updateRoomUser(room_user)
	self.room_users_dict:set(tostring(room_user.user_id), stbl.encode(room_user))
	return room_user
end

---@param room_id integer
---@param user_id integer
---@return any?
function MultiplayerRepo:deleteRoomUser(room_id, user_id)
	local room_user = self:getRoomUser(room_id, user_id)
	if room_user then
		self.room_users_dict:delete(tostring(user_id))
	end
	return room_user
end

return MultiplayerRepo
