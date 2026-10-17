local class = require("class")
local int_rates = require("chart.scoring.int_rates")
local Chartfile = require("sea.chart.Chartfile")
local UserRole = require("sea.access.UserRole")
local SessionInsecure = require("sea.access.SessionInsecure")
local UserLocation = require("sea.access.UserLocation")
local UserInsecure = require("sea.access.UserInsecure")
local Chartplay = require("sea.chart.Chartplay")

---@class sea.ServerDatabaseMigrator
---@operator call: sea.ServerDatabaseMigrator
local ServerDatabaseMigrator = class()

---@param old_repo sea.old.ServerRepo
---@param repos sea.Repos
function ServerDatabaseMigrator:new(old_repo, repos)
	self.old_repo = old_repo
	self.repos = repos
end

function ServerDatabaseMigrator:migrateAll()
	print("migrateChartfiles") self:migrateChartfiles()
	print("migrateChartplays") self:migrateChartplays()
	print("migrateSessions") self:migrateSessions()
	print("migrateUserLocations") self:migrateUserLocations()
	print("migrateUserRoles") self:migrateUserRoles()
	print("migrateUsers") self:migrateUsers()
end

---@return integer
function ServerDatabaseMigrator:migrateChartfiles()
	local chartfiles_repo = self.repos.chartfiles_repo

	local files = self.old_repo:getChartFiles()
	for _, file in ipairs(files) do
		local chartfile = Chartfile()
		chartfile.id = file.id
		chartfile.hash = file.hash
		chartfile.name = file.name
		chartfile.size = file.size
		chartfile.compute_state = "new"
		chartfile.computed_at = 0
		chartfile.creator_id = 0
		chartfile.submitted_at = file.created_at

		chartfiles_repo:createChartfile(chartfile)
	end

	return #files
end

---@param role sea.old.Roles
---@return sea.Role
function ServerDatabaseMigrator:convertRole(role)
	if role == "creator" then
		return "owner"
	end
	---@cast role -sea.old.Roles, +sea.Role
	return role
end

---@return integer
function ServerDatabaseMigrator:migrateUserRoles()
	local users_repo = self.repos.users_repo

	local user_roles = self.old_repo:getUserRoles()
	for _, _user_role in ipairs(user_roles) do
		local user_role = setmetatable({}, UserRole)
		user_role.id = _user_role.id
		user_role.user_id = _user_role.user_id
		user_role.role = self:convertRole(_user_role.role)
		user_role.started_at = 0
		user_role.expires_at = _user_role.expires_at
		user_role.total_time = _user_role.total_time

		users_repo:createUserRole(user_role)
	end

	return #user_roles
end

---@return integer
function ServerDatabaseMigrator:migrateSessions()
	local users_repo = self.repos.users_repo

	local sessions = self.old_repo:getSessions()
	for _, _session in ipairs(sessions) do
		local session = SessionInsecure()
		session.id = _session.id
		session.user_id = _session.user_id
		session.active = _session.active
		session.created_at = _session.created_at
		session.updated_at = _session.updated_at
		session.ip = _session.ip

		users_repo:createSession(session)
	end

	return #sessions
end

---@return integer
function ServerDatabaseMigrator:migrateUserLocations()
	local users_repo = self.repos.users_repo

	local user_locations = self.old_repo:getUserLocations()
	for _, _user_location in ipairs(user_locations) do
		local user_location = UserLocation()
		user_location.id = _user_location.id
		user_location.user_id = _user_location.user_id
		user_location.ip = _user_location.ip
		user_location.created_at = _user_location.created_at
		user_location.updated_at = _user_location.updated_at
		user_location.is_register = _user_location.is_register
		user_location.sessions_count = _user_location.sessions_count

		users_repo:createUserLocation(user_location)
	end

	return #user_locations
end

---@return integer
function ServerDatabaseMigrator:migrateUsers()
	local users_repo = self.repos.users_repo

	local users = self.old_repo:getUsers()
	for _, _user in ipairs(users) do
		local user = UserInsecure()
		user.id = _user.id
		user.email = _user.email
		user.password = _user.password
		user.name = _user.name
		user.latest_activity = _user.latest_activity
		user.created_at = _user.created_at
		user.is_banned = _user.is_banned
		user.is_restricted_info = _user.is_restricted_info
		user.description = _user.description
		user.chartplays_count = _user.scores_count -- recalculate later
		user.chartmetas_count = _user.notecharts_count -- recalculate later
		user.chartdiffs_count = 0 -- recalculate later
		user.chartfiles_upload_size = _user.notecharts_upload_size -- recalculate later
		user.chartplays_upload_size = _user.replays_upload_size -- recalculate later
		user.play_time = _user.play_time
		user.color_left = _user.color_left
		user.color_right = _user.color_right
		user.banner = _user.banner
		user.discord = _user.discord
		user.custom_link = _user.custom_link

		users_repo:createUser(user)
	end

	return #users
end

---@return integer
function ServerDatabaseMigrator:migrateChartplays()
	local charts_repo = self.repos.charts_repo

	local scores = self.old_repo:getScores()
	for _, score in ipairs(scores) do
		local chartplay = Chartplay()

		chartplay.id = score.id
		chartplay.user_id = score.user_id
		chartplay.compute_state = "new"
		chartplay.computed_at = 0
		chartplay.submitted_at = score.created_at

		chartplay.replay_hash = score.replay_hash
		chartplay.pause_count = 0
		chartplay.created_at = score.created_at

		chartplay.hash = score.hash
		chartplay.index = score.index

		chartplay.modifiers = {}
		chartplay.rate = score.rate > 0 and int_rates.round(score.rate) or 1
		chartplay.mode = "mania"

		chartplay.nearest = false
		chartplay.tap_only = false
		chartplay.timings = nil
		chartplay.subtimings = nil
		chartplay.healths = nil
		chartplay.columns_order = nil

		chartplay.custom = false
		chartplay.const = score.const
		chartplay.rate_type = "linear"

		chartplay.judges = {}
		chartplay.accuracy = score.accuracy
		chartplay.max_combo = score.max_combo
		chartplay.miss_count = score.misses_count
		chartplay.not_perfect_count = 0
		chartplay.pass = true
		chartplay.rating = score.rating
		chartplay.rating_pp = 0
		chartplay.rating_msd = 0

		charts_repo:createChartplay(chartplay)
	end

	return #scores
end

return ServerDatabaseMigrator
