local AiRouterConfig = require("docker.AiRouterConfig")

local test = {}

---@return ai.router.Config
local function validConfig()
	local config = assert(loadfile("docker/ai-router-config.example.lua"))()
	config.admin_password = string.rep("a", 32)
	config.mcp_token = string.rep("b", 64)
	return config
end

---@param t testing.T
function test.accepts_private_persistent_configuration(t)
	t:has_not_error(function() AiRouterConfig.validate(validConfig()) end)
	t:has_error(function() AiRouterConfig.validate(assert(loadfile("docker/ai-router-config.example.lua"))()) end)
end

---@param t testing.T
function test.rejects_public_binds_ephemeral_paths_and_weak_secrets(t)
	for key, value in pairs({host = "0.0.0.0", port = 80,
		db_path = "userdata/router.db", network_path = "userdata/network.lua", admin_password = "short", mcp_token = "short"}) do
		local config = validConfig()
		config[key] = value
		t:has_error(function() AiRouterConfig.validate(config) end)
	end
end

return test
