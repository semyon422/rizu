---@alias sphere.AiProviderType "openai_compatible"|"openai_subscription"
---@alias sphere.AiReasoningEffort "none"|"low"|"medium"|"high"|"xhigh"|"max"

---@class sphere.AiProviderConfig
---@field name string
---@field type sphere.AiProviderType
---@field models string[]
---@field order integer?
---@field base_url string?
---@field api_key string?
---@field max_tokens integer?
---@field timeout number
---@field reasoning_effort sphere.AiReasoningEffort?

---@class sphere.AiConfig
---@field active_provider string
---@field active_model string
---@field providers {[string]: sphere.AiProviderConfig}
---@field provider sphere.AiProviderType? Legacy single-provider field.
---@field base_url string? Legacy single-provider field.
---@field api_key string? Legacy single-provider field.
---@field model string? Legacy single-provider field.
---@field max_tokens integer? Legacy single-provider field.
---@field timeout number? Legacy single-provider field.
---@field reasoning_effort sphere.AiReasoningEffort? Legacy single-provider field.

---@type sphere.AiConfig
local ai = {
	active_provider = "",
	active_model = "",
	providers = {},
}

return ai
