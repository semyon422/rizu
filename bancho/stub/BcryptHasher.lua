--- Bcrypt hasher stub for testing.
---
--- Provides an in-memory username→hash map for password verification
--- without requiring the actual bcrypt library.

local class = require("class")

---@class bancho.IBcryptHasher
---@field verify fun(password: string, hash: string): boolean

---@class bancho.stub.BcryptHasher : bancho.IBcryptHasher
local BcryptHasher = class()

function BcryptHasher:new()
	---@type table<string, string> username -> hash
	self._hashes = {}
	return self
end

--- Register a username with its hash.
---@param username string
---@param hash string
function BcryptHasher:set(username, hash)
	self._hashes[username:lower()] = hash
end

--- Verify a password against the stored hash.
---@param username string
---@param password_md5 string
---@return boolean
function BcryptHasher:verify(username, password_md5)
	local hash = self._hashes[username:lower()]
	if not hash then return false end
	return hash == password_md5
end

return BcryptHasher
