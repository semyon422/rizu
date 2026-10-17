local class = require("class")
local UsersAccess = require("sea.access.access.UsersAccess")
local User = require("sea.access.User")
local UserInsecure = require("sea.access.UserInsecure")
local UserLocation = require("sea.access.UserLocation")
local Session = require("sea.access.Session")
local SessionInsecure = require("sea.access.SessionInsecure")
local AuthCode = require("sea.access.AuthCode")
local BanchoCredentials = require("sea.access.BanchoCredentials")

---@class sea.Users
---@operator call: sea.Users
local Users = class()

Users.is_login_enabled = true
Users.is_register_enabled = true
Users.ip_register_delay = 24 * 60 * 60

---@param users_repo sea.UsersRepo
---@param password_hasher sea.IPasswordHasher
---@param email_sender sea.IEmailSender
---@param bancho_credentials? sea.BanchoCredentials
function Users:new(users_repo, password_hasher, email_sender, bancho_credentials)
	self.users_repo = users_repo
	self.password_hasher = password_hasher
	self.email_sender = email_sender
	self.users_access = UsersAccess()
	self.bancho_credentials = bancho_credentials or BanchoCredentials(users_repo)
end

---@param order string?
---@param limit integer?
---@param offset integer?
---@return sea.User[]
function Users:getUsers(order, limit, offset)
	return self.users_repo:getUsers(order, limit, offset)
end

---@return integer
function Users:getUsersCount()
	return self.users_repo:getUsersCount()
end

---@param id integer?
---@return sea.User
function Users:getUser(id)
	if not id then
		return User()
	end
	local user = self.users_repo:getUser(id)
	if not user then
		return User()
	end
	return user
end

---@param name string
---@return sea.User?
function Users:findUserByName(name)
	return self.users_repo:findUserByName(name)
end

---@param _ sea.User
---@param ip string
---@param time integer
---@param user_values sea.UserInsecure
---@return {session: sea.Session, user: sea.User}?
---@return "disabled"|"rate_exceeded"|"email_taken"|"name_taken"?
function Users:register(_, ip, time, user_values)
	if not self.is_register_enabled then
		return nil, "disabled"
	end

	local user_location = self.users_repo:getRecentRegisterUserLocation(ip)
	if user_location and user_location.created_at + self.ip_register_delay > time then
		return nil, "rate_exceeded"
	end

	local email = user_values.email:lower()

	local user = self.users_repo:findUserByEmail(email)
	if user then
		return nil, "email_taken"
	end

	user = self.users_repo:findUserByName(user_values.name)
	if user then
		return nil, "name_taken"
	end

	user = UserInsecure()
	user.name = user_values.name
	user.email = email
	user.password = self.password_hasher:digest(user_values.password)
	user.latest_activity = time
	user.created_at = time

	user = self.users_repo:createUser(user)
	self.bancho_credentials:syncPassword(user.id, user_values.password, time)

	local session = SessionInsecure()
	session.user_id = user.id
	session.active = true
	session.ip = ip
	session.created_at = time
	session.updated_at = time

	session = self.users_repo:createSession(session)

	user_location = UserLocation()
	user_location.user_id = user.id
	user_location.ip = ip
	user_location.created_at = time
	user_location.updated_at = time
	user_location.is_register = true
	user_location.sessions_count = 1

	self.users_repo:createUserLocation(user_location)

	return {session = session, user = user}
end

---@param _ sea.User
---@param ip string
---@param time integer
---@param user_values sea.UserInsecure
---@return {session: sea.Session, user: sea.User}?
---@return "disabled"|"invalid_credentials"?
function Users:login(_, ip, time, user_values)
	if not self.is_login_enabled then
		return nil, "disabled"
	end

	local user = self.users_repo:findUserInsecureByEmail(user_values.email)
	if not user then
		return nil, "invalid_credentials"
	end

	local valid = self.password_hasher:verify(user_values.password, user.password)
	if not valid then
		return nil, "invalid_credentials"
	end

	self.bancho_credentials:syncPassword(user.id, user_values.password, time)
	user = user:hideCredentials()

	local session = SessionInsecure()
	session.active = true
	session.created_at = time
	session.user_id = user.id
	session.active = true
	session.ip = ip
	session.created_at = time
	session.updated_at = time

	session = self.users_repo:createSession(session)

	local user_location = self.users_repo:getUserLocation(user.id, ip)
	if not user_location then
		user_location = UserLocation()
		user_location.user_id = user.id
		user_location.ip = ip
		user_location.created_at = time
		user_location.updated_at = time
		user_location.is_register = false
		user_location.sessions_count = 0
		user_location = assert(self.users_repo:createUserLocation(user_location))
	end

	user_location.sessions_count = user_location.sessions_count + 1
	self.users_repo:updateUserLocation(user_location)

	return {session = session, user = user}
end

---@param user sea.User
---@param session_id integer?
---@return true?
---@return string?
function Users:logout(user, session_id)
	if user:isAnon() or not session_id then
		return nil, "not allowed"
	end

	local session = self.users_repo:getSession(session_id)
	if not session then
		return nil, "not found"
	end

	if session.user_id ~= user.id then
		return nil, "not allowed"
	end

	session.active = false
	self.users_repo:updateSession(session)

	return true
end

---@param user sea.User
---@param user_update sea.UserUpdate
---@param time integer
---@return sea.User?
---@return string?
function Users:updateUser(user, user_update, time)
	if not user_update.id then
		return nil, "not found"
	end

	local target_user = self.users_repo:getUser(user_update.id)

	if not target_user then
		return nil, "not found"
	end

	if not self.users_access:canUpdateSelf(user, target_user, time) then
		return nil, "not allowed"
	end

	if not self.users_access:canUpdateNameGradient(user, target_user, time) then
		user_update.enable_gradient = false
	end

	return self.users_repo:updateUser(user_update)
end

---@param user sea.User
---@param current_password string
---@param new_email string
---@param time integer
---@return sea.User?
---@return string?
function Users:updateEmail(user, current_password, new_email, time)
	if user:isAnon() then
		return nil, "not allowed"
	end

	local target_user = self.users_repo:getUserInsecure(user.id)
	if not target_user then
		return nil, "not found"
	end

	local can = self.users_access:canUpdateSelf(user, target_user, time)
	if not can then
		return nil, "not allowed"
	end

	local valid = self.password_hasher:verify(current_password, target_user.password)
	if not valid then
		return nil, "invalid credentials"
	end

	target_user.email = new_email
	return self.users_repo:updateUser(target_user)
end

---@param user sea.User
---@param current_password string
---@param new_password string
---@param time integer
function Users:updatePassword(user, current_password, new_password, time)
	if user:isAnon() then
		return nil, "not allowed"
	end

	local target_user = self.users_repo:getUserInsecure(user.id)
	if not target_user then
		return nil, "not found"
	end

	local can = self.users_access:canUpdateSelf(user, target_user, time)
	if not can then
		return nil, "not allowed"
	end

	local valid = self.password_hasher:verify(current_password, target_user.password)
	if not valid then
		return nil, "invalid credentials"
	end

	target_user.password = self.password_hasher:digest(new_password)
	target_user = self.users_repo:updateUser(target_user)
	self.bancho_credentials:syncPassword(target_user.id, new_password, time)
	return target_user
end

---@param time integer
---@param code string
---@param new_password string
function Users:updatePasswordUsingCode(time, code, new_password)
	local auth_code = self.users_repo:getAuthCode(code)
	if not auth_code then
		return nil, "code not found"
	elseif auth_code.used then
		return nil, "code used"
	elseif auth_code.expires_at < time then
		return nil, "code expired"
	end

	local user = self.users_repo:getUser(auth_code.user_id)
	if not user then
		return nil, "invalid user"
	end

	auth_code.used = true

	self.users_repo:updateAuthCode(auth_code)

	local user_insecure = UserInsecure()
	user_insecure.id = user.id
	user_insecure.password = self.password_hasher:digest(new_password)

	user_insecure = self.users_repo:updateUser(user_insecure)
	self.bancho_credentials:syncPassword(user.id, new_password, time)
	return user_insecure
end

---@param user sea.User
---@param time integer
---@param target_user_id integer
---@param is_banned boolean
---@return sea.User?
---@return string?
function Users:updateBanned(user, time, target_user_id, is_banned)
	if user.id == target_user_id then
		return nil, "not allowed"
	end

	local target_user = self.users_repo:getUser(target_user_id)
	if not target_user then
		return nil, "not found"
	end

	local can, err = self.users_access:canUpdate(user, target_user, time)
	if not can then
		return nil, "not allowed"
	end

	target_user.is_banned = is_banned
	target_user = self.users_repo:updateUser(target_user)

	return target_user
end

---@param id integer?
---@return sea.Session?
function Users:getSession(id)
	if not id then
		return Session()
	end
	local session = self.users_repo:getSession(id)
	if not session then
		return Session()
	end
	return session
end

---@param req_session sea.Session
---@return sea.Session?
function Users:checkSession(req_session)
	local session = self:getSession(req_session.id)
	if not session or not session.active then
		return
	end

	if session.updated_at ~= req_session.updated_at then
		session.active = false
		self.users_repo:updateSession(session)
		return
	end

	return session
end

---@param user sea.User
---@param session sea.Session
---@return sea.Session?
function Users:updateSession(user, session)
	if user:isAnon() then
		return
	end

	if session.user_id ~= user.id then
		return
	end

	session.updated_at = os.time()
	session = self.users_repo:updateSession(session)

	return session
end

---@param user sea.User
---@param ip string
---@param time integer
---@param target_user_id integer?
---@param _type sea.AuthCodeType
---@param duration integer
---@return sea.AuthCode?
---@return string?
function Users:createAuthCode(user, ip, time, target_user_id, _type, duration)
	local can = self.users_access:canCreateAuthCode(user, time)
	if not can then
		return nil, "not allowed"
	end

	local auth_code = AuthCode()
	auth_code.user_id = target_user_id
	auth_code.type = _type
	auth_code.created_at = time
	auth_code.expires_at = time + duration
	auth_code.ip = ip

	auth_code = self.users_repo:createAuthCode(auth_code)

	return auth_code
end

---@param ip string
---@param email string
---@param time integer
---@param duration integer
---@param rate_limit integer
---@return string?
---@return string?
function Users:createAndSendPasswordResetAuthCode(ip, email, time, duration, rate_limit)
	local auth_code = self.users_repo:getRecentAuthCodeByIp(ip)
	if auth_code and auth_code.created_at + rate_limit > time then
		return nil, "rate limit"
	end

	local user = self.users_repo:findUserByEmail(email)
	if not user then
		-- TODO: log email
		return nil, "user not found"
	end

	local auth_code = AuthCode()
	auth_code.user_id = user.id
	auth_code.type = "password_reset"
	auth_code.created_at = time
	auth_code.expires_at = time + duration
	auth_code.ip = ip

	auth_code = self.users_repo:createAuthCode(auth_code)

	self.email_sender:send(email, ("password reset code: %s"):format(auth_code.code))

	return auth_code.code
end

return Users
