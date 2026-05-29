--- Replay repository backed by SQLite.

local class = require("class")

---@class bancho.ReplayRepo
---@operator call: bancho.ReplayRepo
local ReplayRepo = class()

---@param models rdb.Models
function ReplayRepo:new(models)
	self.models = models
end

--- Save replay data for a score.
---@param score_id integer
---@param data string
---@return boolean
function ReplayRepo:saveReplay(score_id, data)
	local result = self.models.replays:create({score_id = score_id, data = data})
	return result ~= nil
end

--- Get replay data for a score.
---@param score_id integer
---@return string?
function ReplayRepo:getReplay(score_id)
	local row = self.models.replays:find({score_id = score_id})
	return row and row.data or nil
end

return ReplayRepo
