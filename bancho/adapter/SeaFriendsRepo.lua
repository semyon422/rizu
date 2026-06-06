local class = require("class")

---@class bancho.adapter.SeaFriendsRepo
---@operator call: bancho.adapter.SeaFriendsRepo
---@field users_repo sea.UsersRepo
local SeaFriendsRepo = class()

---@param users_repo sea.UsersRepo
function SeaFriendsRepo:new(users_repo)
	self.users_repo = users_repo
end

---@param user_id integer
---@return integer[]
function SeaFriendsRepo:getFriends(user_id)
	return self.users_repo:getUserFriends(user_id)
end

---@param user_id integer
---@param friend_id integer
---@return boolean
function SeaFriendsRepo:addFriend(user_id, friend_id)
	return self.users_repo:addUserFriend(user_id, friend_id)
end

---@param user_id integer
---@param friend_id integer
---@return boolean
function SeaFriendsRepo:removeFriend(user_id, friend_id)
	return self.users_repo:removeUserFriend(user_id, friend_id)
end

---@param user_id integer
---@param friend_id integer
---@return boolean
function SeaFriendsRepo:isFriend(user_id, friend_id)
	return self.users_repo:isUserFriend(user_id, friend_id)
end

return SeaFriendsRepo
