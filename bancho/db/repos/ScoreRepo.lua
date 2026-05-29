--- Score repository backed by SQLite.

local class = require("class")

---@class bancho.ScoreRepo
---@operator call: bancho.ScoreRepo
local ScoreRepo = class()

---@param models rdb.Models
function ScoreRepo:new(models)
	self.models = models
end

--- Find scores by map md5 and mode.
---@param map_md5 string
---@param mode integer
---@return table[]
function ScoreRepo:findScores(map_md5, mode)
	return self.models.scores:select({map_md5 = map_md5, mode = mode}, {
		order = {"pp DESC"},
	})
end

--- Find best score for a user on a map.
---@param map_md5 string
---@param user_id integer
---@param mode integer
---@return table?
function ScoreRepo:findBestScore(map_md5, user_id, mode)
	return self.models.scores:find({map_md5 = map_md5, user_id = user_id, mode = mode}, {
		order = {"pp DESC"},
	})
end

--- Find a score by id.
---@param id integer
---@return table?
function ScoreRepo:findScore(id)
	return self.models.scores:find({id = id})
end

--- Add a score.
---@param score table
---@return integer score_id
function ScoreRepo:addScore(score)
	local result = self.models.scores:create(score)
	return result.id
end

--- Find top scores for a leaderboard.
---@param map_md5 string
---@param mode integer
---@param limit integer
---@return table[]
function ScoreRepo:findTopScores(map_md5, mode, limit)
	return self.models.scores:select({map_md5 = map_md5, mode = mode}, {
		order = {"pp DESC"},
		limit = limit,
	})
end

return ScoreRepo
