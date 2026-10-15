local AiRouterConfig = require("docker.AiRouterConfig")
local http = require("web.http.util")
local Client = require("mcp.Client")

-- Do not print config, bearer tokens or transport exception details to Docker health logs.
local ok = pcall(function()
	local config = AiRouterConfig.load()
	local response = assert(http.request("http://127.0.0.1:28083/v1/models", nil, {timeout = 2}))
	assert(response.status == 401)
	local client = Client({url = "http://127.0.0.1:28084/mcp", token = config.mcp_token, timeout = 2})
	local initialized = client:initialize()
	client:close()
	assert(initialized)
end)
if not ok then
	io.stderr:write("AI router inference/MCP health check failed\n")
	os.exit(1)
end
