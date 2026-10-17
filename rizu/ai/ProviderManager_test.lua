local ProviderManager = require("rizu.ai.ProviderManager")

local test = {}

local function makeOptions(config)
	local saved = 0
	return {
		config = config,
		credentials = {access_token = "", refresh_token = "", expires_at = 0, account_id = ""},
		scheduler = {},
		request = function() error("not used") end,
		open_stream = function() error("not used") end,
		open_url = function() return true end,
		save_config = function() saved = saved + 1 end,
		save_credentials = function() end,
		getSaved = function() return saved end,
	}
end

---@param t testing.T
function test.flattens_providers_and_persists_selection(t)
	local config = {
		active_provider = "local_qwen",
		active_model = "qwen-small",
		providers = {
			openai = {
				name = "OpenAI", type = "openai_subscription", order = 2,
				models = {"gpt-one", "gpt-two"}, timeout = 30, reasoning_effort = "medium",
			},
			local_qwen = {
				name = "Local", type = "openai_compatible", order = 1,
				models = {"qwen-small"}, base_url = "http://localhost/v1", api_key = "", max_tokens = 100, timeout = 10,
			},
		},
	}
	local options = makeOptions(config)
	local manager = ProviderManager(options)
	t:eq(#manager.options, 3)
	t:eq(manager.options[1].label, "Local — qwen-small")
	t:eq(manager:getClient().model, "qwen-small")
	t:eq(manager:getAuth(), nil)

	local client, auth = manager:select(3)
	t:eq(client.model, "gpt-two")
	t:assert(auth)
	t:eq(config.active_provider, "openai")
	t:eq(config.active_model, "gpt-two")
	t:eq(options.getSaved(), 1)
	manager:unload()
end

---@param t testing.T
function test.allows_no_configured_models(t)
	local manager = ProviderManager(makeOptions({
		active_provider = "",
		active_model = "",
		providers = {},
		model = "",
	}))
	t:eq(manager:hasModels(), false)
	t:has_error(function() manager:getClient() end)
end

---@param t testing.T
function test.supports_legacy_single_provider_config(t)
	local config = {
		active_provider = "",
		active_model = "",
		providers = {},
		provider = "openai_compatible",
		base_url = "http://localhost/v1",
		api_key = "",
		model = "legacy-model",
		max_tokens = 100,
		timeout = 10,
		reasoning_effort = "medium",
	}
	local manager = ProviderManager(makeOptions(config))
	t:eq(manager:getSelectedOption().model, "legacy-model")
	t:eq(manager:getClient().base_url, "http://localhost/v1")
end

return test
