---@class sphere.OnlineConfig
---@field url string
---@field tokens {[string]: string}
---@field quick_login_key string
local online = {
	url = "ws://localhost:8180/ws",
	session = {},
	user = {},
	tokens = {},
	quick_login_key = "",
}

return online
