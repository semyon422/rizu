local class = require("class")

---@class rizu.mapperatorinator.GenerationRequest
---@field repository_path string
---@field python_path string
---@field audio_path string
---@field output_path string
---@field gamemode integer
---@field difficulty number
---@field keycount integer
---@field year integer

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

---@param request rizu.mapperatorinator.GenerationRequest
---@return string command
function GenerationRunner:buildCommand(request)
	assert(request.repository_path ~= "", "Mapperatorinator repository path is required")
	assert(request.python_path ~= "", "Mapperatorinator Python path is required")
	assert(request.audio_path ~= "", "Mapperatorinator audio path is required")
	assert(request.output_path ~= "", "Mapperatorinator output path is required")
	local overrides = {
		"audio_path=" .. shellQuote(request.audio_path),
		"output_path=" .. shellQuote(request.output_path),
		"gamemode=" .. request.gamemode,
		("difficulty=%.1f"):format(request.difficulty),
		"keycount=" .. request.keycount,
		"year=" .. request.year,
		"export_osz=false",
		"hydra.run.dir=.",
		"hydra.output_subdir=null",
	}
	return table.concat({
		"cd", shellQuote(request.repository_path), "&&",
		shellQuote(request.python_path), "inference.py",
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
