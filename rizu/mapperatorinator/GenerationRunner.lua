local class = require("class")

---@class rizu.mapperatorinator.GenerationRequest
---@field repository_path string
---@field python_path string
---@field audio_path string
---@field output_path string
---@field model string
---@field gamemode integer
---@field difficulty number
---@field keycount integer
---@field year integer
---@field [string] any

---@class rizu.mapperatorinator.GenerationRunner
---@operator call: rizu.mapperatorinator.GenerationRunner
local GenerationRunner = class()

---@param execute? fun(command: string): boolean|string|number?, string?, integer?
function GenerationRunner:new(execute)
	self.execute = execute or os.execute
end

---@param value string
---@return string
local function shellQuote(value)
	return "'" .. value:gsub("'", "'\\''") .. "'"
end

---@param value string
---@return string
local function hydraString(value)
	return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
end

---@param value any
---@return string
local function hydraValue(value)
	local kind = type(value)
	if kind == "string" then
		return hydraString(value)
	elseif kind == "boolean" or kind == "number" then
		return tostring(value)
	elseif kind == "table" then
		local values = {}
		for _, item in ipairs(value) do
			values[#values + 1] = hydraString(tostring(item))
		end
		return "[" .. table.concat(values, ",") .. "]"
	end
	error("unsupported Hydra value type: " .. kind)
end

local ORDERED_OVERRIDES = {
	"audio_path", "output_path", "beatmap_path", "lora_path", "background",
	"gamemode", "difficulty", "year", "beatmap_id", "mapper_id", "hitsounded",
	"hp_drain_rate", "circle_size", "overall_difficulty", "approach_rate",
	"slider_multiplier", "slider_tick_rate", "keycount", "hold_note_ratio",
	"scroll_speed_ratio", "descriptors", "negative_descriptors", "seed", "device",
	"precision", "attn_implementation", "add_to_beatmap", "overwrite_reference_beatmap",
	"export_osz", "start_time", "end_time", "in_context", "cfg_scale", "temperature",
	"top_p", "super_timing", "generate_positions", "title", "title_unicode", "artist",
	"artist_unicode", "creator", "version", "source", "tags", "preview_time",
}

---@param request rizu.mapperatorinator.GenerationRequest
---@return string command
function GenerationRunner:buildCommand(request)
	assert(request.repository_path ~= "", "Mapperatorinator repository path is required")
	assert(request.python_path ~= "", "Mapperatorinator Python path is required")
	assert(request.audio_path ~= "", "Mapperatorinator audio path is required")
	assert(request.output_path ~= "", "Mapperatorinator output path is required")
	assert(request.model and request.model ~= "", "Mapperatorinator model is required")

	local overrides = {}
	for _, key in ipairs(ORDERED_OVERRIDES) do
		local value = request[key]
		if value ~= nil and value ~= "" then
			overrides[#overrides + 1] = shellQuote(key .. "=" .. hydraValue(value))
		end
	end
	overrides[#overrides + 1] = "hydra.run.dir=."
	overrides[#overrides + 1] = "hydra.output_subdir=null"

	return table.concat({
		"cd", shellQuote(request.repository_path), "&&",
		shellQuote(request.python_path), "inference.py",
		"--config-name", shellQuote(request.model),
		table.concat(overrides, " "),
	}, " ")
end

---@param request rizu.mapperatorinator.GenerationRequest
---@return boolean success
---@return string? error_message
function GenerationRunner:run(request)
	local ok, status, code = self.execute(self:buildCommand(request))
	local success = ok == true or ok == 0
	if success then
		return true
	end
	local exit_code = code or (type(ok) == "number" and math.floor(ok / 256)) or ok
	return false, ("Mapperatorinator exited with %s (%s)."):format(tostring(exit_code), tostring(status or "unknown"))
end

return GenerationRunner
