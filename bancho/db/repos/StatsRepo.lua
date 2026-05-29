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

--- Update stats for a user in a specific mode.
---@param user_id integer
---@param mode integer
---@param fields table
---@return boolean
function StatsRepo:updateStats(user_id, mode, fields)
	fields.user_id = user_id
	fields.mode = mode
	local result = self.models.stats:update(fields, {user_id = user_id, mode = mode})
	return #result > 0
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

return StatsRepo
