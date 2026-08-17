local class = require("class")

---@class rizu.mapperatorinator.AudioFilePicker
---@operator call: rizu.mapperatorinator.AudioFilePicker
local AudioFilePicker = class()

---@param popen? fun(command: string): file*?
function AudioFilePicker:new(popen)
	self.popen = popen or io.popen
end

---@param value string
---@return string
local function shellQuote(value)
	return "'" .. value:gsub("'", "'\\''") .. "'"
end

---@return string? path
---@return string? error_message
function AudioFilePicker:pick()
	if jit.os ~= "Linux" then
		return nil, "The Mapperatorinator prototype currently supports Linux file dialogs only."
	end

	local command = table.concat({
		"zenity --file-selection",
		"--title=" .. shellQuote("Select audio for Mapperatorinator"),
		"--file-filter=" .. shellQuote("Audio files | *.mp3 *.wav *.ogg *.m4a *.flac"),
		"--file-filter=" .. shellQuote("All files | *"),
		"2>/dev/null",
	}, " ")
	local pipe = self.popen(command)
	if not pipe then
		return nil, "Could not launch zenity."
	end
	local path = pipe:read("*l")
	local ok, _, code = pipe:close()
	if not path or path == "" then
		if ok == nil and code == 127 then
			return nil, "zenity is required for the Mapperatorinator audio picker."
		end
		return nil
	end
	return path
end

return AudioFilePicker
