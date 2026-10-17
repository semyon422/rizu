---@class sphere.NeedleConfig
---@field model_path string
---@field debounce_seconds number
---@field max_new_tokens integer

---@type sphere.NeedleConfig
local needle = {
	model_path = "resources/needle/needle-q8-stripped.bin",
	debounce_seconds = 0.25,
	max_new_tokens = 128,
}

return needle
