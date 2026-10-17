local IPasswordHasher = require("sea.access.IPasswordHasher")

---@class sea.FakePasswordHasher: sea.IPasswordHasher
---@operator call: sea.FakePasswordHasher
local FakePasswordHasher = IPasswordHasher + {}

---@param password string
---@return string
function FakePasswordHasher:digest(password)
	return password
end

---@param password string
---@param password_hash string
---@return boolean
function FakePasswordHasher:verify(password, password_hash)
	return password == password_hash
end

return FakePasswordHasher
