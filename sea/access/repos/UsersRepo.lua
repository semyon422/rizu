local class = require("class")
local table_util = require("table_util")
local sql_util = require("rdb.sql_util")
local UserRole = require("sea.access.UserRole")

---@class sea.UsersRepo
---@operator call: sea.UsersRepo
local UsersRepo = class()

---@param models rdb.Models
function UsersRepo:new(models)
	self.models = models
end

---@param order string?
---@param limit integer?
---@param offset integer?
---@return sea.User[]
function UsersRepo:getUsers(order, limit, offset)
	---@type rdb.Options
	local options = {
		limit = limit,
		offset = offset,
	}
	if order then
		options.order = {sql_util.escape_identifier(order) .. " DESC"}
	end
	local users = self.models.users:select(nil, options)
	self.models.users:preload(users, "user_roles")
	return users
end

---@return integer
function UsersRepo:getUsersCount()
	return self.models.users:count()
end

---@return sea.UserInsecure[]
function UsersRepo:getUsersInsecure()
	local users = self.models.users_insecure:select()
	self.models.users:preload(users, "user_roles")
	return users
end

---@param id integer
---@return sea.User?
function UsersRepo:getUser(id)
	local user = self.models.users:find({id = assert(id)})
	self.models.users:preload({user}, "user_roles")
	return user
end

--- Fetch multiple users by ID in a single query.
---@param ids integer[]
---@return sea.User[]
function UsersRepo:getUsersByIds(ids)
	if #ids == 0 then
		return {}
	end
	local users = self.models.users:select({id__in = ids})
	self.models.users:preload(users, "user_roles")
	return users
end

---@param id integer
---@return sea.UserInsecure?
function UsersRepo:getUserInsecure(id)
	local user = self.models.users_insecure:find({id = assert(id)})
	self.models.users:preload({user}, "user_roles")
	return user
end

---@param email string
---@return sea.User?
function UsersRepo:findUserByEmail(email)
	return self.models.users:find({email = assert(email)})
end

---@param email string
---@return sea.UserInsecure?
function UsersRepo:findUserInsecureByEmail(email)
	return self.models.users_insecure:find({email = assert(email)})
end

---@param name string
---@return sea.User?
function UsersRepo:findUserByName(name)
	return self.models.users:find({name = assert(name)})
end

---@param user sea.User
---@return sea.User
function UsersRepo:createUser(user)
	return self.models.users:create(user)
end

---@param user sea.User | sea.UserUpdate
---@return sea.User
function UsersRepo:updateUser(user)
	return self.models.users:update(user, {id = assert(user.id)})[1]
end

---@param id integer
---@return sea.User?
function UsersRepo:deleteUser(id)
	return self.models.users:delete({id = assert(id)})[1]
end

--------------------------------------------------------------------------------

---@param user_id integer
---@return sea.BanchoCredential?
function UsersRepo:getBanchoCredential(user_id)
	return self.models.bancho_credentials:find({user_id = assert(user_id)})
end

---@param bancho_credential sea.BanchoCredential
---@return sea.BanchoCredential
function UsersRepo:createBanchoCredential(bancho_credential)
	return self.models.bancho_credentials:create(bancho_credential)
end

---@param bancho_credential sea.BanchoCredential
---@return sea.BanchoCredential
function UsersRepo:updateBanchoCredential(bancho_credential)
	return self.models.bancho_credentials:update(bancho_credential, {user_id = assert(bancho_credential.user_id)})[1]
end

---@param user_id integer
---@return sea.BanchoCredential?
function UsersRepo:deleteBanchoCredential(user_id)
	return self.models.bancho_credentials:delete({user_id = assert(user_id)})[1]
end

---@param user_id integer
---@return sea.BanchoUserSettings?
function UsersRepo:getBanchoUserSettings(user_id)
	return self.models.bancho_user_settings:find({user_id = assert(user_id)})
end

---@param bancho_user_settings sea.BanchoUserSettings
---@return sea.BanchoUserSettings
function UsersRepo:createBanchoUserSettings(bancho_user_settings)
	return self.models.bancho_user_settings:create(bancho_user_settings)
end

---@param bancho_user_settings sea.BanchoUserSettings
---@return sea.BanchoUserSettings
function UsersRepo:updateBanchoUserSettings(bancho_user_settings)
	return self.models.bancho_user_settings:update(bancho_user_settings, {user_id = assert(bancho_user_settings.user_id)})[1]
end

---@param user_id integer
---@return sea.BanchoUserSettings?
function UsersRepo:deleteBanchoUserSettings(user_id)
	return self.models.bancho_user_settings:delete({user_id = assert(user_id)})[1]
end

--------------------------------------------------------------------------------

---@param user_id integer
---@return sea.UserRole[]
function UsersRepo:getUserRoles(user_id)
	return self.models.user_roles:select({
		user_id = assert(user_id),
	})
end

---@param user_id integer
---@param role sea.Role
---@return sea.UserRole?
function UsersRepo:getUserRole(user_id, role)
	return self.models.user_roles:find({
		user_id = assert(user_id),
		role = assert(role),
	})
end

---@param user_role sea.UserRole
---@return sea.UserRole
function UsersRepo:createUserRole(user_role)
	return self.models.user_roles:create(user_role)
end

---@param user_role sea.UserRole
---@return sea.UserRole
function UsersRepo:updateUserRole(user_role)
	return self.models.user_roles:update(user_role, {id = assert(user_role.id)})[1]
end

---@param user_role sea.UserRole
---@return sea.UserRole
function UsersRepo:updateUserRoleFull(user_role)
	local values = sql_util.null_keys(UserRole.struct)
	table_util.copy(user_role, values)
	return self.models.user_roles:update(values, {id = assert(user_role.id)})[1]
end

---@param user_role sea.UserRole
---@return sea.UserRole
function UsersRepo:deleteUserRole(user_role)
	return self.models.user_roles:delete({id = assert(user_role.id)})
end

--------------------------------------------------------------------------------

---@param user_id integer
---@return sea.UserBadge[]
function UsersRepo:getUserBadges(user_id)
	return self.models.user_badges:select({user_id = assert(user_id)})
end

---@param user_badge sea.UserBadge
function UsersRepo:createUserBadge(user_badge)
	return self.models.user_badges:create(user_badge)
end

---@param user_badge sea.UserBadge
---@return sea.UserBadge?
function UsersRepo:deleteUserBadge(user_badge)
	return self.models.user_badges:delete(user_badge)[1]
end

--------------------------------------------------------------------------------

---@param user_id integer
---@return sea.UserLocation[]
function UsersRepo:getUserLocations(user_id)
	return self.models.user_locations:select({
		user_id = assert(user_id),
	})
end

---@param user_id integer
---@param ip string
---@return sea.UserLocation?
function UsersRepo:getUserLocation(user_id, ip)
	return self.models.user_locations:find({
		user_id = assert(user_id),
		ip = assert(ip),
	})
end

---@param ip string
---@return sea.UserLocation?
function UsersRepo:getRecentRegisterUserLocation(ip)
	return self.models.user_locations:find({
		ip = assert(ip),
		is_register = true,
	}, {order = {"created_at DESC"}})
end

---@param user_location sea.UserLocation
---@return sea.UserLocation?
function UsersRepo:createUserLocation(user_location)
	return self.models.user_locations:create(user_location)
end

---@param user_location sea.UserLocation
---@return sea.UserLocation?
function UsersRepo:updateUserLocation(user_location)
	return self.models.user_locations:update(user_location, {id = assert(user_location.id)})[1]
end

--------------------------------------------------------------------------------

---@param user_id integer
---@return sea.Session[]
function UsersRepo:getSessions(user_id)
	return self.models.sessions:select({user_id = assert(user_id)})
end

---@param user_id integer
---@return sea.Session[]
function UsersRepo:getSessionsInsecure(user_id)
	return self.models.sessions_insecure:select({user_id = assert(user_id)})
end

---@param id integer
---@return sea.Session?
function UsersRepo:getSession(id)
	return self.models.sessions:find({id = assert(id)})
end

---@param id integer
---@return sea.SessionInsecure?
function UsersRepo:getSessionInsecure(id)
	return self.models.sessions_insecure:find({id = assert(id)})
end

---@param session sea.Session
---@return sea.Session?
function UsersRepo:createSession(session)
	return self.models.sessions:create(session)
end

---@param session sea.Session
---@return sea.Session?
function UsersRepo:updateSession(session)
	return self.models.sessions:update(session, {id = assert(session.id)})[1]
end

--------------------------------------------------------------------------------

---@param code string
---@return sea.AuthCode?
function UsersRepo:getAuthCode(code)
	return self.models.auth_codes:find({code = assert(code)})
end

---@param ip string
---@return sea.AuthCode?
function UsersRepo:getRecentAuthCodeByIp(ip)
	return self.models.auth_codes:find({ip = assert(ip)}, {order = {"created_at DESC"}})
end

---@param auth_code sea.AuthCode
---@return sea.AuthCode
function UsersRepo:createAuthCode(auth_code)
	return self.models.auth_codes:create(auth_code)
end

---@param auth_code sea.AuthCode
---@return sea.AuthCode
function UsersRepo:updateAuthCode(auth_code)
	return self.models.auth_codes:update(auth_code, {id = assert(auth_code.id)})[1]
end

---@param id integer
---@return sea.AuthCode?
function UsersRepo:deleteAuthCode(id)
	return self.models.auth_codes:delete({id = assert(id)})[1]
end

--------------------------------------------------------------------------------

---@param reset_before boolean?
function UsersRepo:updateChartmetasCount(reset_before)
	if reset_before then
		self.models._orm.db:query([[
			UPDATE users
			SET chartmetas_count = 0
		]])
	end
	self.models._orm.db:query([[
		UPDATE users
		SET chartmetas_count = count
		FROM (
			SELECT
				COUNT(*) OVER (PARTITION BY user_id) AS count,
				user_id
			FROM chartplays
			INNER JOIN chartmetas ON
				chartplays.hash = chartmetas.hash AND
				chartplays.`index` = chartmetas.`index`
			GROUP BY chartmetas.id
		) AS chartplays
		WHERE users.id == user_id
	]])
end

---@param reset_before boolean?
function UsersRepo:updateChartplaysCount(reset_before)
	if reset_before then
		self.models._orm.db:query([[
			UPDATE users
			SET chartplays_count = 0
		]])
	end
	self.models._orm.db:query([[
		UPDATE users
		SET chartplays_count = chartplays.count
		FROM (
			SELECT
				COUNT(*) AS count,
				user_id
			FROM chartplays
			GROUP BY user_id
		) AS chartplays
		WHERE chartplays.user_id = users.id
	]])
end

---@param reset_before boolean?
function UsersRepo:updatePlayTime(reset_before)
	if reset_before then
		self.models._orm.db:query([[
			UPDATE users
			SET play_time = 0
		]])
	end
	self.models._orm.db:query([[
		UPDATE users
		SET play_time = duration
		FROM (
			SELECT
				SUM(1000.0 * chartdiffs.duration / chartdiffs.rate) AS duration,
				user_id
			FROM chartplays
			INNER JOIN chartdiffs ON
				chartplays.hash = chartdiffs.hash AND
				chartplays.`index` = chartdiffs.`index` AND
				chartplays.modifiers = chartdiffs.modifiers AND
				chartplays.rate = chartdiffs.rate AND
				chartplays.mode = chartdiffs.mode
			GROUP BY user_id
		) AS chartplays
		WHERE users.id == user_id
	]])
end

return UsersRepo
