---@class sphere.Socks5ProxyConfig: rizu.Socks5ProxyConfig

---@class sphere.NetworkConfig
---@field socks5 sphere.Socks5ProxyConfig
local network = {
	socks5 = {
		enabled = false,
		host = "",
		port = 1080,
		username = "",
		password = "",
		whitelist = {},
		blacklist = {
			"localhost",
			"127.0.0.1",
			"::1",
		},
	},
}

return network
