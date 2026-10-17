--- Bancho client configuration.
---
--- Load with: `ClientConfig(overrides)`

local class = require("class")

--- Client configuration with defaults.
---@class bancho.client.ClientConfig
---@field host string Server hostname
---@field port integer Server port
---@field scheme "http"|"https" Protocol scheme
---@field username string Login username
---@field password_md5 string Login password (MD5 hash)
---@field osu_version string osu! client version string
---@field utc_offset integer UTC offset in hours
---@field timeout integer Connection timeout in seconds
---@field max_retries integer Maximum reconnection attempts
---@field pm_private boolean Block non-friend DMs
---@operator call: bancho.client.ClientConfig
local ClientConfig = class()

ClientConfig.defaults = {
	host = "localhost",
	port = 8091,
	scheme = "http",
	username = "",
	password_md5 = "",
	osu_version = "b20240101",
	utc_offset = 0,
	timeout = 5,
	max_retries = 3,
	pm_private = false,
}

--- Create a configuration with optional overrides.
---@param overrides table?
---@return bancho.client.ClientConfig
function ClientConfig:new(overrides)
	local config = {}
	for k, v in pairs(ClientConfig.defaults) do
		config[k] = v
	end
	if overrides then
		for k, v in pairs(overrides) do
			config[k] = v
		end
	end
	return setmetatable(config, { __index = ClientConfig })
end

--- Build the full server URL.
---@return string
function ClientConfig:url()
	return self.scheme .. "://" .. self.host .. ":" .. self.port
end

--- Build the login body string.
--- Format: username\npassword_md5\nosu_version|utc_offset|display_city|client_hashes|pm_private\n
--- client_hashes must end with ':' as bancho.py strips client_hashes[:-1] before splitting.
---@return string
function ClientConfig:login_body()
	return table.concat({
		self.username,
		self.password_md5,
		self.osu_version .. "|" .. self.utc_offset .. "|0|hash1:adapters:hash2:hash3:hash4:|" .. (self.pm_private and "1" or "0"),
	}, "\n") .. "\n"
end

return ClientConfig
