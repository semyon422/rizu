local class = require("class")

---@class rizu.ai.ReadFileTool
---@operator call: rizu.ai.ReadFileTool
---@field name string
---@field description string
---@field input_schema table
---@field annotations mcp.ToolAnnotations
---@field schema aqua.openai.ToolSchema
---@field read_func fun(path: string): string?, string?
---@field max_lines integer
---@field max_chars integer
local ReadFileTool = class()

ReadFileTool.name = "read_file"
ReadFileTool.max_lines = 200
ReadFileTool.max_chars = 32768
ReadFileTool.description = "Read a bounded, numbered line range from a repository source file. Paths are repository-relative; userdata and runtime configuration files are unavailable."
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
			description = "Last line to read, inclusive; at most 200 lines per call",
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

local allowed_roots = {
	"3rd-deps/lua/",
	"aqua/",
	"chart/",
	"gui/",
	"rizu/",
	"sea/",
	"sphere/",
	"yi/",
}

local allowed_root_files = {
	["brand.lua"] = true,
	["conf.lua"] = true,
	["main.lua"] = true,
	["pkg_config.lua"] = true,
}

local allowed_extensions = {
	c = true,
	etlua = true,
	frag = true,
	glsl = true,
	h = true,
	json = true,
	lua = true,
	md = true,
	vert = true,
}

---@param path string
---@return boolean
local function isAllowedPath(path)
	if path == "" or path:find("\0", 1, true) or path:sub(1, 1) == "/" or path:match("^%a:") then
		return false
	end
	for part in path:gmatch("[^/]+") do
		if part == "." or part == ".." or part:sub(1, 1) == "." then
			return false
		end
	end
	local extension = path:match("%.([^. /]+)$")
	if not extension or not allowed_extensions[extension:lower()] then
		return false
	end
	if allowed_root_files[path] then
		return true
	end
	for _, root in ipairs(allowed_roots) do
		if path:sub(1, #root) == root then
			return true
		end
	end
	return false
end

---@param options {read_func: (fun(path: string): string?, string?)?, max_lines: integer?, max_chars: integer?}?
function ReadFileTool:new(options)
	options = options or {}
	self.max_lines = options.max_lines or self.max_lines
	self.max_chars = options.max_chars or self.max_chars
	self.read_func = options.read_func or function(path)
		return love.filesystem.read(path)
	end
end

---@param message string
---@return string
---@return true
local function fail(message)
	return "read_file error: " .. message, true
end

---@param args {[string]: any}
---@return string
---@return boolean? is_error
function ReadFileTool:execute(args)
	if type(args.path) ~= "string" then
		return fail("path must be a string")
	end
	local path = args.path:gsub("\\", "/")
	if not isAllowedPath(path) then
		return fail("path is outside allowed repository source roots")
	end
	local line_start = args.line_start
	local line_end = args.line_end
	if type(line_start) ~= "number" or line_start < 1 or line_start % 1 ~= 0 then
		return fail("line_start must be a positive integer")
	elseif type(line_end) ~= "number" or line_end < line_start or line_end % 1 ~= 0 then
		return fail("line_end must be an integer at or after line_start")
	elseif line_end - line_start + 1 > self.max_lines then
		return fail(("line range exceeds %d lines"):format(self.max_lines))
	end

	local content, err = self.read_func(path)
	if not content then
		return fail(err or "file not found")
	end
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
	local result = table.concat(output, "\n")
	if #result > self.max_chars then
		result = result:sub(1, self.max_chars) .. "\n...[truncated]"
	end
	return result
end

return ReadFileTool
