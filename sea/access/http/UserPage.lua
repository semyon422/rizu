local class = require("class")
local format = require("sea.shared.format")
local time_util = require("time_util")
local math_util = require("math_util")
local dan_list = require("sea.dan.dan_list")
local RatingCalc = require("sea.leaderboards.RatingCalc")
local TotalRating = require("sea.leaderboards.TotalRating")
local ModifierModel = require("sphere.models.ModifierModel")
local Format = require("sphere.views.Format")

---@class sea.UserPage
---@operator call: sea.UserPage
local UserPage = class()

UserPage.activityWeeks = 53

---@param users_access sea.UsersAccess
---@param session_user sea.User
---@param target_user sea.User
---@param leaderboards sea.Leaderboards
---@param dans sea.Dans
function UserPage:new(users_access, session_user, target_user, leaderboards, dans)
	self.usersAccess = users_access
	self.sessionUser = session_user
	self.targetUser = target_user
	self.leaderboards = leaderboards
	self.dans = dans
end

---@return boolean
function UserPage:canUpdate()
	return self.usersAccess:canUpdateSelf(self.sessionUser, self.targetUser, os.time())
end

---@param user_activity_days sea.UserActivityDay[]
---@param timezone sea.Timezone
function UserPage:setActivity(user_activity_days, timezone)
	---@type {[string]: number} activity key should have %d-%m-%Y format
	local activity = {}

	for _, uad in ipairs(user_activity_days) do
		activity[("%02d-%02d-%04d"):format(uad.day, uad.month, uad.year)] = uad.count
	end

	self.activity = activity

	self.currentDate = os.date("!*t", os.time() + timezone:seconds())
	self.currentDateStartTime = os.time({
		year = self.currentDate.year,
		month = self.currentDate.month,
		day = self.currentDate.day,
	})
	self.currentWeekDay = self.currentDate.wday -- Sunday is 1 | Saturday is 7
	self.maxDays = self.activityWeeks * 7 - (7 - self.currentWeekDay)
end

---@return { name: string, span: number }[]
function UserPage:getActivityWeekLabels()
	local t = {}
	---@type string
	local current_month_name
	local span = 0

	for week = 1, self.activityWeeks do
		local delta = (((week - 1) * 7) + 1) - self.maxDays
		local month = os.date("%b", self.currentDateStartTime + (delta * 60 * 60 * 24))

		if not current_month_name then
			current_month_name = month
			span = span + 1
		elseif month ~= current_month_name then
			table.insert(t, {name = current_month_name, span = span})
			current_month_name = month
			span = 1
		else
			span = span + 1
		end
	end

	table.insert(t, {name = current_month_name, span = span})
	return t
end

---@param week_num number
---@return string?
function UserPage:getActivityWeekDayLabel(week_num)
	if week_num == 2 then
		return "Mon"
	elseif week_num == 4 then
		return "Wed"
	elseif week_num == 6 then
		return "Fri"
	end
end

---@return {date: string, activity: integer}[]
--- Returns a table of rows. Row is a day of the week.
--- Activity is a number from 0 to 4.
function UserPage:getActivityRectangles()
	local rows = {}

	for week_day = 1, 7 do
		local rectangles = self.currentWeekDay >= week_day and self.activityWeeks or (self.activityWeeks - 1)
		local row = {}

		for week = 1, rectangles do
			local delta = (((week - 1) * 7) + week_day) - self.maxDays
			local date = os.date("%d-%m-%Y", self.currentDateStartTime + (delta * 60 * 60 * 24))
			local count = self.activity[date] or 0
			local activity = math.min(4, math.ceil(count / 10))
			table.insert(row, {date = date, activity = activity, count = count})
		end

		table.insert(rows, row)
	end

	return rows
end

---@return string
function UserPage:formatLastSeen()
	return time_util.time_ago_in_words(self.targetUser.latest_activity)
end

---@return string
function UserPage:formatPlayTime()
	local play_time = self.targetUser.play_time
	local hours = math.floor(play_time / 3600)
	local minutes = math.floor(play_time % 3600 / 60)

	if minutes < 1 then
		return ("No play time")
	elseif hours < 1 then
		return ("%i minutes"):format(minutes)
	end

	return ("%i hours"):format(hours)
end

---@return string
function UserPage:formatRole()
	local time = os.time()

	if self.targetUser:hasRole("owner", time, true) then
		return "Project leader"
	elseif self.targetUser:hasRole("admin", time, true) then
		return "Admin"
	elseif self.targetUser:hasRole("moderator", time, true) then
		return "Moderator"
	elseif self.targetUser:hasRole("donator", time, true) then
		return "Donator"
	end

	return ""
end

---@param user_id integer
---@return {label: string, value: string}[]
function UserPage:getGeneralStats(user_id)
	local lb_id = 1
	local lb = self.leaderboards:getLeaderboard(lb_id)
	local lb_user = self.leaderboards:getLeaderboardUser(lb_id, user_id)

	if not lb_user or not lb then
		return {}
	end

	local cells = {}

	table.insert(cells, {
		label = RatingCalc:postfix(lb.rating_calc):upper(),
		value = format.float4(lb_user.total_rating),
	})

	table.insert(cells, {
		label = "Accuracy",
		value = ("%0.2f%%"):format(lb_user:getNormAccuracy() * 100),
	})

	-- TODO: Get these values from the main leaderboard.
	-- TODO: People have their preferences in rating calculators, let them choose one or two options in the settings. This is a personal option.
	-- table.insert(cells, {label = "PP", value = "15028"})

	-- Accuracy should always be displayed
	-- table.insert(cells, {label = "Accuracy", value = "90.81%"})

	-- The owner of the profile decides which dans to display
	-- table.insert(cells, {label = "4K Regular dan", value = "Delta"})
	-- table.insert(cells, {label = "Satellite", value = "Lv.6"})

	return cells
end

---@param lb sea.Leaderboard
---@param user_id integer
---@param _type "top"|"first"|"recent"
---@return table
---@return sea.TotalRating
function UserPage:getScores(lb, user_id, _type)
	---@type sea.Chartplayview[]
	local chartplayviews = {}

	if _type == "top" then
		chartplayviews = self.leaderboards:getBestChartplaysFull(lb, user_id)
	elseif _type == "first" then
		chartplayviews = self.leaderboards:getFirstPlaceChartplaysFull(lb, user_id)
	elseif _type == "recent" then
		chartplayviews = self.leaderboards:getRecentChartplaysFull(lb, user_id)
	end

	local total_rating = TotalRating()
	total_rating:calc(chartplayviews)

	local scores = {}

	for i, cpv in ipairs(chartplayviews) do
		local chartmeta = cpv.chartmeta
		local chartdiff = cpv.chartdiff

		---@type number
		local rating = cpv[RatingCalc:column(lb.rating_calc)]
		local artist = chartmeta and chartmeta.artist or "?"
		local title = chartmeta and chartmeta.title or "?"
		local name = chartmeta and chartmeta.name or "?"
		local creator = chartmeta and chartmeta.creator
		local rate = chartdiff and chartdiff.rate or "?"
		local inputmode = chartdiff and Format.inputMode(chartdiff.inputmode) or "?"
		local modifiers = ModifierModel:getString(cpv.modifiers)
		local rating_postfix = RatingCalc:postfix(lb.rating_calc):upper()

		local chart_name = ""

		if creator and creator ~= "" then
			chart_name = ("[%s] %s by %s"):format(inputmode, name, creator)
		else
			chart_name = ("[%s] %s"):format(inputmode, name)
		end

		local mods = {}

		if rate ~= 1 then
			table.insert(mods, ("%sX"):format(rate))
		end
		if cpv.const then
			table.insert(mods, "CONST")
		end
		if cpv.tap_only then
			table.insert(mods, "TAP")
		end
		table.insert(mods, modifiers)

		scores[i] = {
			song_name = ("%s - %s"):format(artist, title),
			chart_name = chart_name,
			mods_line = table.concat(mods, " "),
			norm_accuracy = cpv:getNormAccuracy(),
			time_since = time_util.time_ago_in_words(cpv.created_at),
			grade = cpv:getGrade(),
			rating = lb.rating_calc == "pp" and math_util.round(rating, 1) or ("%0.2f"):format(rating),
			rating_postfix = rating_postfix,
		}
	end

	return scores, total_rating
end

---@alias sea.UserPage.DanRow { category: string, name: string, rate: number, level: number, time: number }}

function UserPage:getDanClears()
	local clears = self.dans:getUserDanClears(self.targetUser)

	---@type {[string]: sea.UserPage.DanRow }
	local peaks = {}

	for _, clear in ipairs(clears) do
		local dan = dan_list[clear.dan_id]
		local peak = peaks[dan.category]

		if (peak and dan.level > peak.level) or not peak then
			peak = {
				category = dan.category,
				name = dan.name,
				rate = clear.rate,
				time = clear.time,
				level = dan.level
			}
		end

		peaks[dan.category] = peak
	end

	---@type sea.UserPage.DanRow[]
	local t = {}

	for _, v in pairs(peaks) do
		table.insert(t, v)
	end

	table.sort(t, function (a, b)
		return a.level > b.level
	end)

	return t
end

return UserPage
