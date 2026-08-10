local class = require("class")
local ActivityTimezones = require("sea.activity.ActivityTimezones")
local table_util = require("table_util")
local sql_util = require("rdb.sql_util")

---@class sea.ActivityRepo
---@operator call: sea.ActivityRepo
local ActivityRepo = class()

---@param models rdb.Models
function ActivityRepo:new(models)
	self.models = models
end

---@param user_id integer
---@param timezone sea.Timezone
---@param start_date sea.ActivityDate
---@param end_date sea.ActivityDate
---@return sea.UserActivityDay[]
function ActivityRepo:getUserActivityDays(user_id, timezone, start_date, end_date)
	local sy, sm, sd = start_date.year, start_date.month, start_date.day
	local ey, em, ed = end_date.year, end_date.month, end_date.day

	return self.models.user_activity_days:select({
		user_id = assert(user_id),
		timezone = assert(timezone),
		{"or", {year__gt = sy}, {year = sy, month__gt = sm}, {year = sy, month = sm, day__gte = sd}},
		{"or", {year__lt = ey}, {year = ey, month__lt = em}, {year = ey, month = em, day__lte = ed}},
	}, {order = {"year", "month", "day"}})
end

---@param user_id integer
function ActivityRepo:recomputeUserActivity(user_id)
	assert(user_id)
	self.models._orm.db:query("DELETE FROM user_activity_days WHERE user_id = ?", {user_id})
	local chartplays = self.models.chartplays:select({user_id = user_id, compute_state = "valid"})
	for _, chartplay in ipairs(chartplays) do
		self:increaseUserActivity(user_id, chartplay.submitted_at)
	end
end

---@param user_id integer
---@param time integer
function ActivityRepo:increaseUserActivity(user_id, time)
	assert(user_id)
	assert(time)

	for _, tz in ipairs(ActivityTimezones) do
		local adjusted_time = time + tz:seconds()
		local year = os.date("!%Y", adjusted_time)
		local month = os.date("!%m", adjusted_time)
		local day = os.date("!%d", adjusted_time)

		self.models._orm.db:query([[
			INSERT OR REPLACE INTO user_activity_days 
				(user_id, timezone, year, month, day, count)
			VALUES (
				?, ?, ?, ?, ?,
				COALESCE(
					(
						SELECT count FROM user_activity_days 
						WHERE user_id = ? AND timezone = ? AND year = ? AND month = ? AND day = ?
					),
					0
				) + 1
			)
		]], {
			user_id, tz:encode(), year, month, day,
			user_id, tz:encode(), year, month, day
		})
	end
end

return ActivityRepo
