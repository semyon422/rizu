local class = require("class")

---@class bancho.adapter.SeaFavouritesRepo
---@operator call: bancho.adapter.SeaFavouritesRepo
---@field users_repo sea.UsersRepo
local SeaFavouritesRepo = class()

---@param users_repo sea.UsersRepo
function SeaFavouritesRepo:new(users_repo)
	self.users_repo = users_repo
end

---@param user_id integer
---@return integer[]
function SeaFavouritesRepo:getFavourites(user_id)
	return self.users_repo:getUserOsuFavourites(user_id)
end

---@param user_id integer
---@param set_id integer
---@return boolean
function SeaFavouritesRepo:addFavourite(user_id, set_id)
	return self.users_repo:addUserOsuFavourite(user_id, set_id)
end

---@param user_id integer
---@param set_id integer
---@return boolean
function SeaFavouritesRepo:removeFavourite(user_id, set_id)
	return self.users_repo:removeUserOsuFavourite(user_id, set_id)
end

return SeaFavouritesRepo
