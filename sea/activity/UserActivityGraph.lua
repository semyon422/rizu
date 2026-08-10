local class = require("class")

---@class sea.UserActivityGraph
---@operator call: sea.UserActivityGraph
local UserActivityGraph = class()

---@param activity_repo sea.ActivityRepo
function UserActivityGraph:new(activity_repo)
	self.activity_repo = activity_repo
end

---@param user_id integer
---@param timezone sea.Timezone
---@param start_date sea.ActivityDate
---@param end_date sea.ActivityDate
---@return sea.UserActivityDay[]
function UserActivityGraph:getUserActivityDays(user_id, timezone, start_date, end_date)
	return self.activity_repo:getUserActivityDays(user_id, timezone, start_date, end_date)
end

---@param user_id integer
function UserActivityGraph:recomputeUserActivity(user_id)
	self.activity_repo:recomputeUserActivity(user_id)
end

---@param user_id integer
---@param time integer
function UserActivityGraph:increaseUserActivity(user_id, time)
	self.activity_repo:increaseUserActivity(user_id, time)
end

return UserActivityGraph
