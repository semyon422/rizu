local bcrypt = require("bcrypt")
local digest = require("digest")
local class = require("class")
local BanchoCredential = require("sea.access.BanchoCredential")

---@class sea.BanchoCredentials
---@operator call: sea.BanchoCredentials
---@field users_repo sea.UsersRepo
local BanchoCredentials = class()

---@param users_repo sea.UsersRepo
function BanchoCredentials:new(users_repo)
	self.users_repo = users_repo
end

---@param user_id integer
---@param password string
---@param time integer
---@return sea.BanchoCredential
function BanchoCredentials:syncPassword(user_id, password, time)
	local password_md5 = digest.hash("md5", password, true)
	local password_md5_bcrypt = bcrypt.digest(password_md5, 10)

	local credential = self.users_repo:getBanchoCredential(user_id)
	if credential then
		credential.password_md5_bcrypt = password_md5_bcrypt
		credential.updated_at = time
		return self.users_repo:updateBanchoCredential(credential)
	end

	credential = BanchoCredential()
	credential.user_id = user_id
	credential.password_md5_bcrypt = password_md5_bcrypt
	credential.created_at = time
	credential.updated_at = time
	return self.users_repo:createBanchoCredential(credential)
end

return BanchoCredentials
