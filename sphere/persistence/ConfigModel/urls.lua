---@class sphere.ServerConfig
---@field name string
---@field url string

---@class sphere.UrlsConfig
---@field update string
---@field servers sphere.ServerConfig[]
local urls = {
	update = "",
	servers = {
		{name = "Local", url = "ws://localhost:8180/ws"},
	},
}

return urls
