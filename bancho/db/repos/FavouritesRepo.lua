--- Favourites repository backed by SQLite.

local class = require("class")

---@class bancho.FavouritesRepo
---@operator call: bancho.FavouritesRepo
local FavouritesRepo = class()

---@param models rdb.Models
function FavouritesRepo:new(models)
	self.models = models
end

--- Get favourited set IDs for a user.
---@param user_id integer
---@return integer[]
function FavouritesRepo:getFavourites(user_id)
	local rows = self.models.favourites:select({user_id = user_id})
	---@type integer[]
	local ids = {}
	for _, row in ipairs(rows) do
		table.insert(ids, row.set_id)
	end
	return ids
end

--- Add a favourite.
---@param user_id integer
---@param set_id integer
---@return boolean
function FavouritesRepo:addFavourite(user_id, set_id)
	local result = self.models.favourites:create({user_id = user_id, set_id = set_id})
	return result ~= nil
end

--- Remove a favourite.
---@param user_id integer
---@param set_id integer
---@return boolean
function FavouritesRepo:removeFavourite(user_id, set_id)
	local result = self.models.favourites:delete({user_id = user_id, set_id = set_id})
	return #result > 0
end

return FavouritesRepo
