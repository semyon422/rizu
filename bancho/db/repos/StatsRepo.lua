--- Stats repository backed by SQLite.

local class = require("class")

---@class bancho.StatsRepo
---@operator call: bancho.StatsRepo
local StatsRepo = class()

---@param models rdb.Models
function StatsRepo:new(models)
	self.models = models
end

--- Get stats for a user in a specific mode.
---@param user_id integer
---@param mode integer
---@return table?
function StatsRepo:getStats(user_id, mode)
	return self.models.stats:find({user_id = user_id, mode = mode})
end

--- Update or create stats for a user in a specific mode.
--- Reads current row, merges with new fields, then writes back.
--- Creates the row if it doesn't exist (upsert).
---@param user_id integer
---@param mode integer
---@param fields table
---@return boolean
function StatsRepo:updateStats(user_id, mode, fields)
	local current = self.models.stats:find({user_id = user_id, mode = mode})
	if current then
		for k, v in pairs(fields) do
			current[k] = v
		end
		self.models.stats:update(current, {user_id = user_id, mode = mode})
	else
		fields.user_id = user_id
		fields.mode = mode
		self.models.stats:insert({fields})
	end
	return true
end

--- Create stats rows for all modes (0=std, 1=taiko, 2=catch, 3=mania).
---@param user_id integer
---@return boolean
function StatsRepo:createAllModes(user_id)
	for mode = 0, 3 do
		self.models.stats:create({
			user_id = user_id,
			mode = mode,
		})
	end
	return true
end

--- Calculate global rank for a user in a specific mode.
--- Rank is 1-based position among all users sorted by pp DESC.
---@param user_id integer
---@param mode integer vanilla mode (0-3)
---@param pp number user's current pp
---@return integer rank
function StatsRepo:getGlobalRank(user_id, mode, pp)
	local orm = self.models._orm
	local rows = orm:query(
		[[SELECT COUNT(*) as higher FROM stats
		WHERE mode = ? AND pp > ?]],
		{mode, pp}
	)
	return (rows[1] and rows[1].higher or 0) + 1
end

return StatsRepo
