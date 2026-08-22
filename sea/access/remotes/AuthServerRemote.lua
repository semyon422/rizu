local class = require("class")
local valid = require("valid")
local table_util = require("table_util")
local UserInsecure = require("sea.access.UserInsecure")
local Session = require("sea.access.Session")
local User = require("sea.access.User")

---@class sea.AuthServerRemote: sea.IServerRemoteContext
---@operator call: sea.AuthServerRemote
local AuthServerRemote = class()

---@param users sea.Users
---@param sessions web.Sessions
---@param user_connections sea.UserConnections
---@param on_auth? fun(peer: sea.Peer, old_user: sea.User)
function AuthServerRemote:new(users, sessions, user_connections, on_auth)
	self.users = users
	self.sessions = sessions
	self.user_connections = user_connections
	self.on_auth = on_auth
end

---@return sea.Session?
function AuthServerRemote:checkSession()
	return self.users:checkSession(self.session)
end

---@return sea.Session?
function AuthServerRemote:updateSession()
	return self.users:updateSession(self.user, self.session)
end

local function clear_copy(src, dst)
	table_util.clear(dst)
	table_util.copy(src, dst)
end

---@param token string
---@return boolean?
---@return string?
function AuthServerRemote:loginByToken(token)
	local session_data, err = self.sessions:decode(token)
	if not session_data then
		return nil, err
	end

	-- Web session signing adds this field, but it is not part of sea.Session.
	---@cast session_data {[string]: any}
	session_data.csrf_token = nil
	local ok, err = Session.validate(session_data)
	if not ok then
		return nil, err
	end

	---@cast session_data +sea.Session

	local session = self.users:checkSession(session_data)
	if not session then
		return
	end

	local old_user = table_util.copy(self.user, User())

	clear_copy(session, self.session)
	clear_copy(self.users:getUser(session.user_id), self.user)

	self.user_connections:heartbeat(self.peer_id, self.user.id)

	if self.on_auth then
		self.on_auth(self.peer, old_user)
	end

	return true
end

---@deprecated
---@param req_session sea.Session
---@return boolean?
function AuthServerRemote:loginSession(req_session)
	if not req_session.id then
		return
	end

	local session = self.users:checkSession(req_session)
	if not session then
		return
	end

	local old_user = table_util.copy(self.user, User())

	clear_copy(session, self.session)
	clear_copy(self.users:getUser(session.user_id), self.user)

	self.user_connections:heartbeat(self.peer_id, self.user.id)

	if self.on_auth then
		self.on_auth(self.peer, old_user)
	end

	return true
end

---@param email string
---@param password string
---@return {session: sea.Session, user: sea.User, token: string}?
---@return string?
function AuthServerRemote:login(email, password)
	local user = UserInsecure()
	user.email = email
	user.password = password

	local ok, err = valid.format(user:validateLogin())
	if not ok then
		return nil, "login: " .. err
	end

	local su, err = self.users:login(self.user, self.ip, os.time(), user)
	if not su then
		return nil, err
	end

	local old_user = table_util.copy(self.user, User())

	clear_copy(su.session, self.session)
	clear_copy(su.user, self.user)

	self.user_connections:heartbeat(self.peer_id, self.user.id)

	if self.on_auth then
		self.on_auth(self.peer, old_user)
	end

	return {
		session = su.session,
		user = su.user,
		token = self.sessions:encode(su.session),
	}
end

---@return true?
---@return string?
function AuthServerRemote:logout()
	local old_user = table_util.copy(self.user, User())
	local old_id = self.user.id
	local ok, err = self.users:logout(self.user, self.session.id)
	if not ok then
		return nil, err
	end

	clear_copy(Session(), self.session)
	clear_copy(User(), self.user)

	self.user_connections:heartbeat(self.peer_id, nil)

	if self.on_auth then
		self.on_auth(self.peer, old_user)
	end

	return true
end

return AuthServerRemote
