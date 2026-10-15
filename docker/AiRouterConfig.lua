---@class docker.AiRouterConfig
local AiRouterConfig = {}

AiRouterConfig.path = "/router-state/config.lua"

---@param config ai.router.Config
function AiRouterConfig.validate(config)
	assert(config.host == "127.0.0.1" and config.port == 28083, "Compose router must listen on 127.0.0.1:28083")
	assert(config.mcp_host == "127.0.0.1" and config.mcp_port == 28084, "Compose MCP must listen on 127.0.0.1:28084")
	assert(config.db_path == "/router-state/router.db", "Compose router database must use its persistent mount")
	assert(config.network_path == "/router-state/network.lua", "Compose router network config must use its persistent mount")
	assert(type(config.admin_password) == "string" and #config.admin_password >= 16
		and config.admin_password ~= "REPLACE_WITH_RANDOM_ADMIN_PASSWORD", "Set a random router admin password")
	assert(type(config.mcp_token) == "string" and #config.mcp_token >= 32
		and config.mcp_token ~= "REPLACE_WITH_RANDOM_MCP_TOKEN", "Set a random router MCP token")
end

---@param path string?
---@return ai.router.Config
function AiRouterConfig.load(path)
	local loader = assert(loadfile(path or AiRouterConfig.path), "Missing router config; prepare server-state/ai-router/config.lua")
	local config = loader()
	assert(type(config) == "table", "Router config must return a table")
	AiRouterConfig.validate(config)
	return config
end

return AiRouterConfig
