--- User repository backed by SQLite.

local class = require("class")

---@class bancho.UserRepo
---@operator call: bancho.UserRepo
local UserRepo = class()

---@param models rdb.Models
function UserRepo:new(models)
	self.models = models
end

--- Find a user by id.
---@param id integer
---@return table?
function UserRepo:findUser(id)
	return self.models.users:find({id = id})
end

--- Find a user by name (case-insensitive).
---@param name string
---@return table?
function UserRepo:findUserByName(name)
	-- SQLite doesn't support case-insensitive collation by default on TEXT,
	-- but we can use COLLATE NOCASE.
	-- However, the ORM uses = comparisons, so we do a manual query.
	return self.models.users.orm:query(
		"SELECT * FROM users WHERE name = ? COLLATE NOCASE LIMIT 1",
		{name}
	)[1]
end

--- Find a user by name and password MD5.
---@param name string
---@param password_md5 string
---@return table?
function UserRepo:findUserByNameAndPassword(name, password_md5)
	---@type rdb.Row?
	local user = self.models.users.orm:query(
		"SELECT * FROM users WHERE name = ? COLLATE NOCASE AND pw_md5 = ? LIMIT 1",
		{name, password_md5}
	)[1]
	return user
end

--- Create a new user.
---@param name string
---@param email string
---@param pw_bcrypt string
---@param country string
---@return table?
function UserRepo:createUser(name, email, pw_bcrypt, country)
	return self.models.users:create({
		name = name,
		email = email,
		pw_bcrypt = pw_bcrypt,
		pw_md5 = "",
		country_acronym = country or "",
		country_code = country or "",
	})
end

--- Partially update user fields.
---@param id integer
---@param fields table
---@return boolean
function UserRepo:partialUpdate(id, fields)
	local result = self.models.users:update(fields, {id = id})
	return #result > 0
end

--- Find a user by email.
---@param email string
---@return table?
function UserRepo:findByEmail(email)
	return self.models.users:find({email = email})
end

--- Find a user by token.
---@param token string
---@return table?
function UserRepo:findByToken(token)
	return self.models.users:find({token = token})
end

return UserRepo
