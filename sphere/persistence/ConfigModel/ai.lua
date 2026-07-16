---@class sphere.AiConfig
---@field base_url string
---@field api_key string
---@field model string
---@field max_tokens integer
---@field timeout number

---@type sphere.AiConfig
local ai = {
	base_url = "",
	api_key = "",
	model = "",
	max_tokens = 4096,
	timeout = 300,
}

return ai
