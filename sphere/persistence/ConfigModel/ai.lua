---@class sphere.AiConfig
---@field provider "openai_compatible"|"openai_subscription"
---@field base_url string
---@field api_key string
---@field model string
---@field max_tokens integer
---@field timeout number
---@field reasoning_effort "none"|"low"|"medium"|"high"|"xhigh"|"max"

---@type sphere.AiConfig
local ai = {
	provider = "openai_compatible",
	base_url = "",
	api_key = "",
	model = "",
	max_tokens = 4096,
	timeout = 300,
	reasoning_effort = "medium",
}

return ai
