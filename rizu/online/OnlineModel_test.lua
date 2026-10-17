local OnlineModel = require("rizu.online.OnlineModel")

local test = {}

---@param selected_url string
---@param servers {name: string, url: string}[]
local function createModel(selected_url, servers)
	---@type string?
	local written
	local config_model = {
		configs = {
			online = {url = selected_url},
			urls = {servers = servers},
		},
		write = function(_, name) written = name end,
	}
	local sea_client = {network = {}, pending_returns = {}}
	local model = OnlineModel(config_model --[[@as sphere.ConfigModel]], sea_client --[[@as rizu.SeaClient]])
	return model, config_model, function() return written end
end

---@param t testing.T
function test.keeps_configured_server_url(t)
	local model, _, getWritten = createModel("wss://second.example/ws", {
		{name = "First", url = "wss://first.example/ws"},
		{name = "Second", url = "wss://second.example/ws"},
	})

	t:eq(model:getServerUrl(), "wss://second.example/ws")
	t:eq(getWritten(), nil)
end

---@param t testing.T
function test.recovers_missing_server_url(t)
	local model, config_model, getWritten = createModel("wss://removed.example/ws", {
		{name = "First", url = "wss://first.example/ws"},
		{name = "Second", url = "wss://second.example/ws"},
	})

	t:eq(model:getServerUrl(), "wss://first.example/ws")
	t:eq(config_model.configs.online.url, "wss://first.example/ws")
	t:eq(getWritten(), "online")
end

---@param t testing.T
function test.rejects_empty_server_list(t)
	local model = createModel("wss://removed.example/ws", {})
	t:has_error(function()
		model:getServerUrl()
	end, "no online servers configured")
end

return test
