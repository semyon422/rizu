local IResource = require("web.framework.IResource")
local UserPage = require("sea.access.http.UserPage")
local UserSettingsPage = require("sea.access.http.UserSettingsPage")
local UserUpdate = require("sea.access.UserUpdate")
local http_util = require("web.http.util")
local string_util = require("string_util")
local json = require("web.json")
local valid = require("valid")
local types = require("sea.shared.types")
local Roles = require("sea.access.Roles")
local Timezone = require("sea.activity.Timezone")
local ActivityDate = require("sea.activity.ActivityDate")
local brand = require("brand")

---@class sea.UserResource: web.IResource
---@operator call: sea.UserResource
local UserResource = IResource + {}

UserResource.routes = {
	{"/users/update_email", {
		GET = "getUpdateEmail",
		POST = "updateEmail",
	}},
	{"/users/update_password", {
		GET = "getUpdatePassword",
		POST = "updatePassword",
	}},
	{"/users/:user_id", {
		GET = "getUser",
	}},
	{"/users/:user_id/update_description", {
		POST = "updateDescription",
	}},
	{"/users/:user_id/sessions", {
		GET = "getUserSessions",
	}},
	{"/users/:user_id/settings", {
		GET = "getUserSettings",
		POST = "updateSettings",
	}},
	{"/users/:user_id/teams", {
		GET = "getUserTeams",
	}},
	{"/users/:user_id/roles", {
		GET = "getUserRoles",
	}},
	{"/users/:user_id/roles/:role", {
		GET = "getUserRole",
		DELETE = "deleteUserRole",
		POST = "createUserRole",
		PATCH = "updateUserRole",
	}},
	{"/users/:user_id/ban", {
		POST = "banUser",
		DELETE = "unbanUser",
	}},
	{"/users/:user_id/badges", {
		GET = "getUserBadges",
		POST = "createUserBadge",
	}},
	{"/users/:user_id/badges/:badge", {
		DELETE = "deleteUserBadge",
	}},
}

---@param users sea.Users
---@param user_roles sea.UserRoles
---@param user_badges sea.UserBadges
---@param leaderboards sea.Leaderboards
---@param dans sea.Dans
---@param user_activity_graph sea.UserActivityGraph
---@param views web.Views
---@param user_connections sea.UserConnections
function UserResource:new(users, user_roles, user_badges, leaderboards, dans, user_activity_graph, views, user_connections)
	self.users = users
	self.user_roles = user_roles
	self.user_badges = user_badges
	self.leaderboards = leaderboards
	self.dans = dans
	self.user_activity_graph = user_activity_graph
	self.views = views
	self.user_connections = user_connections

	self.testActivity = {
		["21-03-2025"] = 30,
		["24-03-2025"] = 40,
		["25-03-2025"] = 10,
	}
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:getUser(req, res, ctx)
	local user = self.users:getUser(tonumber(ctx.path_params.user_id))

	if user:isAnon() then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	user.online = self.user_connections:isUserOnline(user.id)

	local leaderboard_id = tonumber(ctx.query.lb) or 1
	ctx.leaderboard = assert(self.leaderboards:getLeaderboard(leaderboard_id))
	ctx.leaderboard_user = self.leaderboards:getLeaderboardUser(leaderboard_id, user.id)
	ctx.leaderboard_user_history = self.leaderboards:getLeaderboardUserHistory(leaderboard_id, user.id)

	local page = UserPage(self.users.users_access, ctx.session_user, user, self.leaderboards, self.dans)

	local date_t = os.date("*t", os.time() + 3600 * 24)
	---@cast date_t -string

	local user_activity_days = self.user_activity_graph:getUserActivityDays(
		user.id,
		user.activity_timezone,
		ActivityDate(date_t.year - 1, date_t.month, date_t.day),
		ActivityDate(date_t.year, date_t.month, date_t.day)
	)
	page:setActivity(user_activity_days, user.activity_timezone)

	ctx.page = page
	ctx.user = user

	ctx.query.scores = ctx.query.scores or "top"

	ctx.general_stats = page:getGeneralStats(user.id)
	ctx.dan_clears = page:getDanClears()

	ctx.main_container_type = "none"
	ctx.edit_description = page:canUpdate() and ctx.query.edit_description == "true"
	ctx.leaderboards = self.leaderboards:getLeaderboards()
	ctx.scores, ctx.total_rating = page:getScores(ctx.leaderboard, user.id, ctx.query.scores)

	ctx.meta_tags["title"] = ("%s's profile - %s"):format(ctx.user.name or "Unknown", brand.name)
	ctx.meta_tags["profile:username"] = ctx.user.name
	if ctx.user.avatar and ctx.user.avatar ~= "" then
		ctx.meta_tags["og:image"] = ctx.user.avatar
	end

	if #ctx.general_stats ~= 0 then
		local s = {}
		for i, v in ipairs(ctx.general_stats) do
			s[i] = ("%s: %s"):format(v.label, v.value)
		end
		ctx.meta_tags["description"] = table.concat(s, " | ")
	end

	ctx.user_badges = self.user_badges:getUserBadges(user)

	self.views:render_send(res, "sea/access/http/user.etlua", ctx, true)
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:updateDescription(req, res, ctx)
	local user_id = tonumber(ctx.path_params.user_id)
	if not user_id then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	---@type {[string]: any}?, string?
	local description, _ = http_util.get_json(req)

	if not description then
		res.status = 400
		res:send("invalid json")
		return
	end

	local encoded = json.encode(description)

	if not description.ops then
		encoded = ""
	end

	if #description.ops == 1 and description.ops[1].insert == "\n" then
		encoded = ""
	end

	local user_update = UserUpdate()
	user_update.id = user_id
	user_update.description = encoded

	local user, err = self.users:updateUser(ctx.session_user, user_update, ctx.time)

	if not user then
		---@cast err -?
		res.status = 400
		res:send(err)
		return
	end

	res.status = 200
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:getUserSessions(req, res, ctx)
	self.views:render_send(res, "sea/access/http/user_sessions.etlua", ctx, true)
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:getUserSettings(req, res, ctx)
	ctx.user = self.users:getUser(tonumber(ctx.path_params.user_id))

	local page = UserSettingsPage(ctx.session_user, ctx.user)
	ctx.page = page

	if not page:canUpdate() then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	ctx.main_container_type = "vertically_centered"
	self.views:render_send(res, "sea/access/http/user_settings.etlua", ctx, true)
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:getUpdateEmail(req, res, ctx)
	if not self.users.users_access:canUpdateSelf(ctx.session_user, ctx.session_user, ctx.time) then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	ctx.main_container_type = "vertically_centered"
	self.views:render_send(res, "sea/access/http/user_update_email.etlua", ctx, true)
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:getUpdatePassword(req, res, ctx)
	if not self.users.users_access:canUpdateSelf(ctx.session_user, ctx.session_user, ctx.time) then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	ctx.main_container_type = "vertically_centered"
	self.views:render_send(res, "sea/access/http/user_update_password.etlua", ctx, true)
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:getUserTeams(req, res, ctx)
	self.views:render_send(res, "sea/access/http/user_teams.etlua", ctx, true)
end

---@param str string?
---@return integer
local function hex_to_integer(str)
	if not str then
		return 0
	end
	return tonumber(str:sub(2, #str), 16) or 0
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:updateSettings(req, res, ctx)
	local user_id = tonumber(ctx.path_params.user_id)
	if not user_id then
		res.status = 404
		return
	end

	local body_params, err = http_util.get_form(req)
	if not body_params then
		---@cast err -?
		res.status = 400
		res:send(err)
		return
	end

	---@type sea.UserUpdate
	local user_update = UserUpdate()
	user_update.id = user_id
	user_update.name = body_params.name
	user_update.discord = body_params.discord
	user_update.activity_timezone = Timezone.decode(tonumber(body_params.activity_timezone) or 0)
	user_update.banner = body_params.banner_url
	user_update.avatar = body_params.avatar_url
	user_update.enable_gradient = body_params.enable_gradient == "on"
	user_update.color_left = hex_to_integer(body_params.color_left)
	user_update.color_right = hex_to_integer(body_params.color_right)
	user_update.country_code = body_params.country_code

	local ok, errs = user_update:validate()

	if not ok then
		---@cast errs -?
		res.status = 400
		res:send(table.concat(errs, ", "))
		return
	end

	local user, err = self.users:updateUser(ctx.session_user, user_update, ctx.time)

	if not user then
		---@cast err -?
		res.status = 400
		res:send(err)
		return
	end

	res.headers:set("HX-Location", ("/users/%i/settings"):format(user_id))
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:updateEmail(req, res, ctx)
	local body_params, err = http_util.get_form(req)
	if not body_params then
		---@cast err -?
		res.status = 400
		res:send(err)
		return
	end

	local ok, err = valid.format(valid.struct({
		current_password = types.password_any_length,
		new_email = types.email,
	})(body_params))

	if not ok then
		ctx.main_container_type = "vertically_centered"
		ctx.update_email_error = err
		self.views:render_send(res, "sea/access/http/user_update_email.etlua", ctx, true)
		return
	end

	local current_password = body_params.current_password
	local new_email = body_params.new_email

	local user, err = self.users:updateEmail(ctx.session_user, current_password, new_email, ctx.time)

	if not user then
		ctx.main_container_type = "vertically_centered"
		ctx.update_email_error = err
		self.views:render_send(res, "sea/access/http/user_update_email.etlua", ctx, true)
		return
	end

	res.headers:set("HX-Location", ("/users/%i/settings"):format(ctx.session_user.id))
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:updatePassword(req, res, ctx)
	local body_params, err = http_util.get_form(req)
	if not body_params then
		---@cast err -?
		res.status = 400
		res:send(err)
		return
	end

	local validate_update_password = valid.wrap_format(valid.struct({
		current_password = types.password_any_length,
		new_password = types.password,
		confirm_new_password = function(v)
			return v == body_params.new_password, "not matching new_password"
		end,
	}))

	local ok, err = validate_update_password(body_params)

	if not ok then
		ctx.main_container_type = "vertically_centered"
		ctx.update_password_error = err
		self.views:render_send(res, "sea/access/http/user_update_password.etlua", ctx, true)
		return
	end

	local current_password = body_params.current_password
	local new_password = body_params.new_password

	local user, err = self.users:updatePassword(ctx.session_user, current_password, new_password, ctx.time)

	if not user then
		ctx.main_container_type = "vertically_centered"
		ctx.update_password_error = err
		self.views:render_send(res, "sea/access/http/user_update_password.etlua", ctx, true)
		return
	end

	res.headers:set("HX-Location", ("/users/%i/settings"):format(ctx.session_user.id))
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:getUserRoles(req, res, ctx)
	local user_id = tonumber(ctx.path_params.user_id)
	if not user_id then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	local user = self.users:getUser(user_id)
	if user:isAnon() then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	ctx.user = user

	self.views:render_send(res, "sea/access/http/user_roles.etlua", ctx, true)
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:createUserRole(req, res, ctx)
	local user_id = tonumber(ctx.path_params.user_id)
	local role = ctx.path_params.role
	if not user_id or not types.new_enum(Roles.enum)(role) then
		res.status = 404
		res:send("not found")
		return
	end

	local user = self.users:getUser(user_id)
	if user:isAnon() then
		res.status = 404
		res:send("not found")
		return
	end

	local user_role, err = self.user_roles:createRole(ctx.session_user, os.time(), user_id, role)
	if not user_role then
		---@cast err -?
		res.status = 403
		res:send(err)
		return
	end

	res.headers:set("HX-Location", ("/users/%s/roles"):format(user_id))
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:getUserRole(req, res, ctx)
	local user_id = tonumber(ctx.path_params.user_id)
	local role = ctx.path_params.role
	if not user_id or not types.new_enum(Roles.enum)(role) then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	local user_role = self.user_roles:getRole(user_id, role)
	local user = self.users:getUser(user_id)

	if user:isAnon() or not user_role then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	ctx.user = user
	ctx.user_role = user_role

	self.views:render_send(res, "sea/access/http/user_role.etlua", ctx, true)
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:deleteUserRole(req, res, ctx)
	local user_id = tonumber(ctx.path_params.user_id)
	local role = ctx.path_params.role
	if not user_id or not types.new_enum(Roles.enum)(role) then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	local user_role, err = self.user_roles:deleteRole(ctx.session_user, os.time(), user_id, role)
	if not user_role then
		---@cast err -?
		res.status = 403
		res:send(err)
		return
	end

	res.headers:set("HX-Location", ("/users/%s/roles"):format(user_id))
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:updateUserRole(req, res, ctx)
	local user_id = tonumber(ctx.path_params.user_id)
	local role = ctx.path_params.role
	if not user_id or not types.new_enum(Roles.enum)(role) then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	local body_params, err = http_util.get_form(req)
	if not body_params then
		---@cast err -?
		res.status = 400
		res:send(err)
		return
	end

	---@type sea.UserRole?, string?
	local user_role, err

	local duration = tonumber(body_params.duration)
	local unexpire = body_params.unexpire == "true"
	if duration then
		user_role, err = self.user_roles:addTimeRole(ctx.session_user, os.time(), user_id, role, duration)
	elseif unexpire then
		user_role, err = self.user_roles:makeUnexpirableRole(ctx.session_user, os.time(), user_id, role)
	end

	if not user_role then
		---@cast err -?
		res.status = 403
		res:send(err)
		return
	end

	res.headers:set("HX-Location", ("/users/%s/roles/%s"):format(user_id, role))
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:banUser(req, res, ctx)
	local user_id = tonumber(ctx.path_params.user_id)
	if not user_id then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	local user, err = self.users:updateBanned(ctx.session_user, os.time(), user_id, true)
	if not user then
		---@cast err -?
		res.status = 403
		res:send(err)
		return
	end

	res.headers:set("HX-Location", ("/users/%s/settings"):format(user_id))
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:unbanUser(req, res, ctx)
	local user_id = tonumber(ctx.path_params.user_id)
	if not user_id then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	local user, err = self.users:updateBanned(ctx.session_user, os.time(), user_id, false)
	if not user then
		---@cast err -?
		res.status = 403
		res:send(err)
		return
	end

	res.headers:set("HX-Location", ("/users/%s/settings"):format(user_id))
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:getUserBadges(req, res, ctx)
	local user_id = tonumber(ctx.path_params.user_id)
	if not user_id then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	local user = self.users:getUser(user_id)
	if user:isAnon() then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	ctx.user = user
	ctx.user_badges = self.user_badges:getUserBadges(user)

	self.views:render_send(res, "sea/access/http/user_badges.etlua", ctx, true)
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:createUserBadge(req, res, ctx)
	local user_id = tonumber(ctx.path_params.user_id)
	if not user_id then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	local user = self.users:getUser(user_id)
	if user:isAnon() then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	local body_params, err = http_util.get_form(req)
	if not body_params then
		---@cast err -?
		res.status = 400
		res:send(err)
		return
	end

	local badge = body_params.badge or ""
	badge = string_util.trim(badge)

	local user_badge, err = self.user_badges:createUserBadge(ctx.session_user, os.time(), user_id, badge)

	if not user_badge then
		res.status = 400
		res:send(err)
		return
	end

	ctx.user = user
	ctx.user_badges = self.user_badges:getUserBadges(user)

	self.views:render_send(res, "sea/access/http/user_badges.etlua", ctx, true)
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function UserResource:deleteUserBadge(req, res, ctx)
	local user_id = tonumber(ctx.path_params.user_id)
	if not user_id then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	local user = self.users:getUser(user_id)
	if user:isAnon() then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		return
	end

	local badge = ctx.path_params.badge

	local user_badge, err = self.user_badges:deleteUserBadge(ctx.session_user, os.time(), user_id, badge)

	if not user_badge then
		res.status = 400
		res:send(err)
		return
	end

	ctx.user = user
	ctx.user_badges = self.user_badges:getUserBadges(user)
	self.views:render_send(res, "sea/access/http/user_badges.etlua", ctx, true)
end

return UserResource
