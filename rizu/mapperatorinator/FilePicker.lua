local class = require("class")

---@class rizu.mapperatorinator.FilePicker
---@operator call: rizu.mapperatorinator.FilePicker
local FilePicker = class()

---@param popen? fun(command: string): file*?
function FilePicker:new(popen)
	self.popen = popen or io.popen
end

---@param value string
---@return string
local function shellQuote(value)
	return "'" .. value:gsub("'", "'\\''") .. "'"
end

---@param command string
---@return string? path
---@return string? error_message
function FilePicker:run(command)
	if jit.os ~= "Linux" then
		return nil, "Mapperatorinator file dialogs currently support Linux only."
	end
	local pipe = self.popen(command .. " 2>/dev/null")
	if not pipe then
		return nil, "Could not launch zenity."
	end
	local path = pipe:read("*l")
	local ok, _, code = pipe:close()
	if not path or path == "" then
		if ok == nil and code == 127 then
			return nil, "zenity is required for Mapperatorinator file dialogs."
		end
		return nil
	end
	return path
end

---@param title string
---@param filters string[]?
---@return string? path
---@return string? error_message
function FilePicker:open(title, filters)
	local parts = {"zenity --file-selection", "--title=" .. shellQuote(title)}
	for _, filter in ipairs(filters or {}) do
		parts[#parts + 1] = "--file-filter=" .. shellQuote(filter)
	end
	parts[#parts + 1] = "--file-filter=" .. shellQuote("All files | *")
	return self:run(table.concat(parts, " "))
end

---@param title string
---@param filename string?
---@param filters string[]?
---@return string? path
---@return string? error_message
function FilePicker:save(title, filename, filters)
	local parts = {
		"zenity --file-selection --save --confirm-overwrite",
		"--title=" .. shellQuote(title),
	}
	if filename and filename ~= "" then
		parts[#parts + 1] = "--filename=" .. shellQuote(filename)
	end
	for _, filter in ipairs(filters or {}) do
		parts[#parts + 1] = "--file-filter=" .. shellQuote(filter)
	end
	return self:run(table.concat(parts, " "))
end

return FilePicker
