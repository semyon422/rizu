local bit = require("bit")
local bcrypt = require("bcrypt")
local class = require("class")
local BanchoUserSettings = require("sea.access.BanchoUserSettings")
local Privileges = require("bancho.constants.Privileges")

---@class bancho.adapter.SeaUserRepo
---@operator call: bancho.adapter.SeaUserRepo
---@field users_repo sea.UsersRepo
local SeaUserRepo = class()

---@param users_repo sea.UsersRepo
function SeaUserRepo:new(users_repo)
	self.users_repo = users_repo
end

---@param user sea.User|sea.UserInsecure
---@return integer
function SeaUserRepo:getPrivileges(user)
	local priv = Privileges.UNRESTRICTED
	local time = os.time()

	if user:hasRole("verified", time) then
		priv = bit.bor(priv, Privileges.VERIFIED)
	end
	if user:hasRole("donator", time) then
		priv = bit.bor(priv, Privileges.SUPPORTER)
	end
	if user:hasRole("moderator", time) then
		priv = bit.bor(priv, Privileges.MODERATOR)
	end
	if user:hasRole("admin", time) or user:hasRole("owner", time) then
		priv = bit.bor(priv, Privileges.ADMINISTRATOR)
	end

	return priv
end

---@param user sea.User|sea.UserInsecure
---@return table
function SeaUserRepo:toBanchoUser(user)
	local settings = self.users_repo:getBanchoUserSettings(user.id) or BanchoUserSettings()

	return {
		id = user.id,
		name = user.name,
		email = user.email,
		pw_bcrypt = user.password,
		priv = self:getPrivileges(user),
		country_acronym = user.country_code,
		country_code = user.country_code,
		silence_end = 0,
		token = "",
		is_restricted = user.is_banned,
		is_bot = false,
		created_at = user.created_at,
		utc_offset = settings.utc_offset,
		pm_private = settings.pm_private,
		stealth = settings.stealth,
		away_msg = settings.away_msg,
		pres_filter = settings.pres_filter,
	}
end

---@param id integer
---@return table?
function SeaUserRepo:findUser(id)
	local user = self.users_repo:getUserInsecure(id)
	if not user then
		return nil
	end
	return self:toBanchoUser(user)
end

---@param name string
---@return table?
function SeaUserRepo:findUserByName(name)
	local user = self.users_repo:findUserByName(name)
	if not user then
		return nil
	end
	local insecure_user = self.users_repo:getUserInsecure(user.id)
	if not insecure_user then
		return nil
	end
	return self:toBanchoUser(insecure_user)
end

--- Transitional auth bridge.
--- First prefers Sea-owned Bancho credentials when present. Falls back to the
--- legacy transitional behavior where the main Sea password hash itself is
--- expected to match `bcrypt(md5(password))`.
---@param name string
---@param password_md5 string
---@return table?
function SeaUserRepo:findUserByNameAndPassword(name, password_md5)
	local user = self.users_repo.models.users_insecure:find({
		[{"name = ? COLLATE NOCASE"}] = name,
	})
	if not user then
		return nil
	end
	self.users_repo.models.users:preload({user}, "user_roles")

	local credential = self.users_repo:getBanchoCredential(user.id)
	if credential then
		if not bcrypt.verify(password_md5, credential.password_md5_bcrypt) then
			return nil
		end
	elseif not bcrypt.verify(password_md5, user.password) then
		return nil
	end

	return self:toBanchoUser(user)
end

---@param name string
---@param email string
---@param pw_bcrypt string
---@param country string
---@return table?
function SeaUserRepo:createUser(name, email, pw_bcrypt, country)
	local user = self.users_repo.models.users_insecure.metatable()
	user.name = name
	user.email = email
	user.password = pw_bcrypt
	user.country_code = country or "xx"
	user.latest_activity = 0
	user.created_at = os.time()

	user = self.users_repo:createUser(user)

	local settings = BanchoUserSettings()
	settings.user_id = user.id
	self.users_repo:createBanchoUserSettings(settings)

	return self:findUser(user.id)
end

---@param id integer
---@param fields table
---@return boolean
function SeaUserRepo:partialUpdate(id, fields)
	local user = self.users_repo:getUserInsecure(id)
	if not user then
		return false
	end

	for key in pairs(fields) do
		if key ~= "name" and key ~= "email" and key ~= "country_code" and key ~= "is_restricted" then
			return false
		end
	end

	if fields.name ~= nil then
		user.name = fields.name
	end
	if fields.email ~= nil then
		user.email = fields.email
	end
	if fields.country_code ~= nil then
		user.country_code = fields.country_code
	end
	if fields.is_restricted ~= nil then
		user.is_banned = not not fields.is_restricted
	end

	self.users_repo:updateUser(user)
	return true
end

---@param email string
---@return table?
function SeaUserRepo:findByEmail(email)
	local user = self.users_repo:findUserInsecureByEmail(email)
	if not user then
		return nil
	end
	return self:toBanchoUser(user)
end

---@param id integer
---@param fields table
function SeaUserRepo:updateSessionPrefs(id, fields)
	local settings = self.users_repo:getBanchoUserSettings(id)
	if not settings then
		settings = BanchoUserSettings()
		settings.user_id = id
		settings = self.users_repo:createBanchoUserSettings(settings)
	end

	local allowed = {
		utc_offset = true,
		pm_private = true,
		stealth = true,
		away_msg = true,
		pres_filter = true,
	}

	for key, value in pairs(fields) do
		if allowed[key] then
			settings[key] = value
		end
	end

	self.users_repo:updateBanchoUserSettings(settings)
end

return SeaUserRepo
