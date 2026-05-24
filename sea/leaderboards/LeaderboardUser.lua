local class = require("class")
local erfunc = require("chart.scoring.erfunc")

---@class sea.LeaderboardUser
---@operator call: sea.LeaderboardUser
---@field id integer
---@field leaderboard_id integer
---@field user_id integer
---@field total_rating number
---@field total_accuracy number
---@field total_plays integer
---@field ranked_plays integer
---@field rank integer
---@field updated_at integer
---@field history sea.LeaderboardUserHistory?
local LeaderboardUser = class()

LeaderboardUser.change_days = 31

---@return number
function LeaderboardUser:getNormAccuracy()
	return erfunc.erf(0.032 / (self.total_accuracy * math.sqrt(2)))
end

---@param days integer?
---@return integer
function LeaderboardUser:getRankChange(days)
	local history = self.history
	if not history then return 0 end
	return self.rank - history:getRank(days or self.change_days)
end

---@param days integer?
---@return integer
function LeaderboardUser:getRatingChange(days)
	local history = self.history
	if not history then return 0 end
	return self.total_rating - history:getRating(days or self.change_days)
end

---@param days integer?
---@return integer
function LeaderboardUser:getAccuracyChange(days)
	local history = self.history
	if not history then return 0 end
	return self.total_accuracy - history:getAccuracy(days or self.change_days)
end

return LeaderboardUser
