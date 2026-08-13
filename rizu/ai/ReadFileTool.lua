local class = require("class")
local utf8validate = require("utf8validate")

---@class rizu.ai.ReadFileTool
---@operator call: rizu.ai.ReadFileTool
---@field name string
---@field description string
---@field input_schema table
---@field annotations mcp.ToolAnnotations
---@field schema aqua.openai.ToolSchema
---@field fs fs.IFilesystem
---@field max_chars integer
local ReadFileTool = class()

ReadFileTool.name = "read_file"
ReadFileTool.max_chars = 32768
ReadFileTool.description = "Read a numbered line range from a file available through the game's filesystem. Paths are repository-relative."
ReadFileTool.input_schema = {
	type = "object",
	properties = {
		path = {
			type = "string",
			description = "Repository-relative source path, such as rizu/net/NetworkService.lua",
		},
		line_start = {
			type = "integer",
			minimum = 1,
			description = "First line to read, inclusive",
		},
		line_end = {
			type = "integer",
			minimum = 1,
			description = "Last line to read, inclusive",
		},
	},
	required = {"path", "line_start", "line_end"},
	additionalProperties = false,
}
ReadFileTool.annotations = {
	readOnlyHint = true,
	destructiveHint = false,
	idempotentHint = true,
	openWorldHint = false,
}
ReadFileTool.schema = {
	type = "function",
	["function"] = {
		name = ReadFileTool.name,
		description = ReadFileTool.description,
		strict = true,
		parameters = ReadFileTool.input_schema,
	},
}

---@param fs fs.IFilesystem
function ReadFileTool:new(fs)
	self.fs = fs
end

---@param message string
---@return string
---@return true
local function fail(message)
	return "read_file error: " .. message, true
end

---@param path string
---@return string
local function normalizePath(path)
	return (path:gsub("\\", "/"))
end

---@param output string
---@param max_chars integer
---@return string
local function truncate(output, max_chars)
	if #output <= max_chars then
		return output
	end
	return output:sub(1, max_chars) .. "\n...[truncated]"
end

---@param args {[string]: any}
---@return string
---@return boolean? is_error
function ReadFileTool:execute(args)
	if type(args.path) ~= "string" then
		return fail("path must be a string")
	end
	local path = normalizePath(args.path)
	if path == "" or path:find("\0", 1, true) then
		return fail("path must be a non-empty filesystem path")
	end
	local line_start = args.line_start
	local line_end = args.line_end
	if type(line_start) ~= "number" or line_start < 1 or line_start % 1 ~= 0 then
		return fail("line_start must be a positive integer")
	elseif type(line_end) ~= "number" or line_end < line_start or line_end % 1 ~= 0 then
		return fail("line_end must be an integer at or after line_start")
	end

	local content, err = self.fs:read(path)
	if not content then
		return fail(err or "file not found")
	end
	---@type string[]
	local lines = {}
	for line in (content .. "\n"):gmatch("(.-)\n") do
		local clean_line = line:gsub("\r$", "")
		table.insert(lines, clean_line)
	end
	if line_start > #lines then
		return fail(("line_start exceeds file length (%d lines)"):format(#lines))
	end
	line_end = math.min(line_end, #lines)
	local output = {("%s:%d-%d of %d"):format(path, line_start, line_end, #lines)}
	for line_number = line_start, line_end do
		table.insert(output, ("%d: %s"):format(line_number, lines[line_number]))
	end
	local result = truncate(table.concat(output, "\n"), self.max_chars)
	return utf8validate(result)
end

return ReadFileTool
