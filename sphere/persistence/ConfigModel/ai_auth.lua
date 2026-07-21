---@class sphere.AiAuthConfig
---@field access_token string
---@field refresh_token string
---@field expires_at integer
---@field account_id string

---@type sphere.AiAuthConfig
local ai_auth = {
	access_token = "",
	refresh_token = "",
	expires_at = 0,
	account_id = "",
}

return ai_auth
