local class = require("class")
local OpenAiClient = require("ai.openai.Client")
local SubscriptionAuth = require("ai.openai.SubscriptionAuth")
local SubscriptionClient = require("ai.openai.SubscriptionClient")

---@class rizu.ai.ModelOption
---@field provider_id string
---@field provider_name string
---@field model string
---@field label string

---@class rizu.ai.ProviderManagerOptions
---@field config sphere.AiConfig
---@field credentials sphere.AiAuthConfig
---@field scheduler web.CosocketScheduler
---@field request aqua.openai.RequestFunc
---@field open_stream aqua.openai.OpenStreamFunc
---@field open_url fun(url: string): boolean
---@field save_config fun()
---@field save_credentials fun()

---@class rizu.ai.ProviderManager
---@operator call: rizu.ai.ProviderManager
---@field config sphere.AiConfig
---@field options rizu.ai.ModelOption[]
---@field selected_index integer
---@field clients {[string]: aqua.openai.Client|aqua.openai.SubscriptionClient}
---@field auth aqua.openai.SubscriptionAuth?
local ProviderManager = class()

---@param config sphere.AiConfig
local function addLegacyProvider(config)
	if next(config.providers) or not config.model or config.model == "" then return end
	config.providers.legacy = {
		name = config.provider == "openai_subscription" and "OpenAI" or "OpenAI compatible",
		type = config.provider or "openai_compatible",
		base_url = config.base_url,
		api_key = config.api_key,
		models = {config.model},
		max_tokens = config.max_tokens,
		timeout = config.timeout,
		reasoning_effort = config.reasoning_effort,
	}
	config.active_provider = "legacy"
	config.active_model = config.model
end

---@param options rizu.ai.ProviderManagerOptions
function ProviderManager:new(options)
	self.config = options.config
	self.credentials = options.credentials
	self.scheduler = options.scheduler
	self.request = options.request
	self.open_stream = options.open_stream
	self.open_url = options.open_url
	self.save_config = options.save_config
	self.save_credentials = options.save_credentials
	self.clients = {}
	addLegacyProvider(self.config)

	local provider_ids = {}
	for provider_id in pairs(self.config.providers) do table.insert(provider_ids, provider_id) end
	table.sort(provider_ids, function(a, b)
		local pa, pb = self.config.providers[a], self.config.providers[b]
		return (pa.order or math.huge) < (pb.order or math.huge)
			or (pa.order == pb.order and a < b)
	end)
	self.options = {}
	for _, provider_id in ipairs(provider_ids) do
		local provider = self.config.providers[provider_id]
		assert(provider.type == "openai_compatible" or provider.type == "openai_subscription", "invalid AI provider: " .. provider_id)
		assert(type(provider.name) == "string" and provider.name ~= "", "AI provider has no name: " .. provider_id)
		assert(type(provider.models) == "table" and #provider.models > 0, "AI provider has no models: " .. provider_id)
		for _, model in ipairs(provider.models) do
			assert(type(model) == "string" and model ~= "", "AI model must be a non-empty string")
			table.insert(self.options, {
				provider_id = provider_id,
				provider_name = provider.name,
				model = model,
				label = provider.name .. " — " .. model,
			})
		end
	end
	self.selected_index = 1
	for index, model_option in ipairs(self.options) do
		if model_option.provider_id == self.config.active_provider and model_option.model == self.config.active_model then
			self.selected_index = index
			break
		end
	end
end

---@param model_option rizu.ai.ModelOption
---@return aqua.openai.SubscriptionAuth?
function ProviderManager:getOptionAuth(model_option)
	local provider = self.config.providers[model_option.provider_id]
	if provider.type ~= "openai_subscription" then return end
	if not self.auth then
		self.auth = SubscriptionAuth({
			scheduler = self.scheduler,
			credentials = self.credentials,
			save_credentials = self.save_credentials,
			open_url = self.open_url,
			request = self.request,
		})
	end
	return self.auth
end

---@param model_option rizu.ai.ModelOption
---@return aqua.openai.Client|aqua.openai.SubscriptionClient
function ProviderManager:createClient(model_option)
	local provider = self.config.providers[model_option.provider_id]
	if provider.type == "openai_subscription" then
		return SubscriptionClient({
			auth = assert(self:getOptionAuth(model_option)),
			model = model_option.model,
			reasoning_effort = assert(provider.reasoning_effort),
			timeout = assert(provider.timeout),
			open_stream = self.open_stream,
		})
	end
	return OpenAiClient({
		base_url = assert(provider.base_url),
		api_key = provider.api_key or self.config.api_key,
		model = model_option.model,
		max_tokens = provider.max_tokens,
		timeout = assert(provider.timeout),
		request = self.request,
		open_stream = self.open_stream,
	})
end

---@return boolean
function ProviderManager:hasModels()
	return #self.options > 0
end

---@return rizu.ai.ModelOption
function ProviderManager:getSelectedOption()
	return assert(self.options[self.selected_index], "no AI models configured")
end

---@return aqua.openai.Client|aqua.openai.SubscriptionClient
function ProviderManager:getClient()
	local model_option = self:getSelectedOption()
	local key = model_option.provider_id .. "\0" .. model_option.model
	if not self.clients[key] then self.clients[key] = self:createClient(model_option) end
	return self.clients[key]
end

---@return aqua.openai.SubscriptionAuth?
function ProviderManager:getAuth()
	return self:getOptionAuth(self:getSelectedOption())
end

---@param index integer
---@return aqua.openai.Client|aqua.openai.SubscriptionClient
---@return aqua.openai.SubscriptionAuth?
function ProviderManager:select(index)
	assert(self.options[index], "invalid AI model index")
	self.selected_index = index
	local model_option = self:getSelectedOption()
	self.config.active_provider = model_option.provider_id
	self.config.active_model = model_option.model
	self.save_config()
	return self:getClient(), self:getAuth()
end

function ProviderManager:unload()
	if self.auth then self.auth:unload() end
end

return ProviderManager
