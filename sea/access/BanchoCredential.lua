local class = require("class")
local valid = require("valid")
local types = require("sea.shared.types")

---@class sea.BanchoCredential
---@operator call: sea.BanchoCredential
---@field user_id integer
---@field password_md5_bcrypt string
---@field created_at integer
---@field updated_at integer
local BanchoCredential = class()

BanchoCredential.struct = {
	user_id = types.integer,
	password_md5_bcrypt = types.string,
	created_at = types.integer,
	updated_at = types.integer,
}

local validate_bancho_credential = valid.struct(BanchoCredential.struct)

---@return true?
---@return string|valid.Errors?
function BanchoCredential:validate()
	return validate_bancho_credential(self)
end

return BanchoCredential
