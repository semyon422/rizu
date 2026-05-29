--- Friends repository backed by SQLite.

local class = require("class")

---@class bancho.FriendsRepo
---@operator call: bancho.FriendsRepo
local FriendsRepo = class()

---@param models rdb.Models
function FriendsRepo:new(models)
	self.models = models
end

--- Get friend IDs for a user.
---@param user_id integer
---@return integer[]
function FriendsRepo:getFriends(user_id)
	local rows = self.models.friends:select({user_id = user_id})
	---@type integer[]
	local ids = {}
	for _, row in ipairs(rows) do
		table.insert(ids, row.friend_id)
	end
	return ids
end

--- Add a friend.
---@param user_id integer
---@param friend_id integer
---@return boolean
function FriendsRepo:addFriend(user_id, friend_id)
	local result = self.models.friends:create({user_id = user_id, friend_id = friend_id})
	return result ~= nil
end

--- Remove a friend.
---@param user_id integer
---@param friend_id integer
---@return boolean
function FriendsRepo:removeFriend(user_id, friend_id)
	local result = self.models.friends:delete({user_id = user_id, friend_id = friend_id})
	return #result > 0
end

return FriendsRepo
