local class = require("class")

---@class sea.UserConnectionsRepo
---@operator call: sea.UserConnectionsRepo
local UserConnectionsRepo = class()

---@param dict web.ISharedDict
function UserConnectionsRepo:new(dict)
	self.dict = dict
end

---@private
function UserConnectionsRepo:_getConnKey(peer_id)
	return "c:" .. tostring(peer_id)
end

---@param peer_id string
---@param user_id? integer
---@param ttl integer
function UserConnectionsRepo:setConnection(peer_id, user_id, ttl)
	self.dict:set(self:_getConnKey(peer_id), user_id or true, ttl)
end

---@param peer_id string
---@return boolean
function UserConnectionsRepo:hasConnection(peer_id)
	return self.dict:get(self:_getConnKey(peer_id)) ~= nil
end

---@param peer_id string
---@return integer|true|nil
function UserConnectionsRepo:getConnectionUser(peer_id)
	return self.dict:get(self:_getConnKey(peer_id))
end

---@param peer_id string
function UserConnectionsRepo:removeConnection(peer_id)
	self.dict:delete(self:_getConnKey(peer_id))
end

---@param callback fun(user_id: integer|true, peer_id: string)
function UserConnectionsRepo:forEachConnection(callback)
	local keys = self.dict:get_keys(0)
	for _, key in ipairs(keys) do
		if key:sub(1, 2) == "c:" then
			local user_id = self.dict:get(key)
			if user_id ~= nil then
				---@cast user_id -string
				callback(user_id, key:sub(3))
			end
		end
	end
end

---@return integer
function UserConnectionsRepo:getGlobalCount()
	local count = 0
	self:forEachConnection(function()
		count = count + 1
	end)
	return count
end

--- Check if a user has any active connections.
--- Derived from c: keys — no separate TTL key needed.
---@param user_id integer
---@return boolean
function UserConnectionsRepo:isUserOnline(user_id)
	return #self:getPeerIdsByUserId(user_id) > 0
end

---@param user_id integer
---@return string[] peer_ids
function UserConnectionsRepo:getPeerIdsByUserId(user_id)
	---@type string[]
	local peer_ids = {}
	local keys = self.dict:get_keys(0)
	for _, key in ipairs(keys) do
		if key:sub(1, 2) == "c:" then
			local conn_user_id = self.dict:get(key)
			if conn_user_id == user_id then
				table.insert(peer_ids, key:sub(3))
			end
		end
	end
	return peer_ids
end

return UserConnectionsRepo
