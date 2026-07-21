local class = require("class")
local utf8validate = require("utf8validate")

---@class rizu.ai.SearchSourceTool
---@operator call: rizu.ai.SearchSourceTool
---@field name string
---@field description string
---@field input_schema table
---@field annotations mcp.ToolAnnotations
---@field schema aqua.openai.ToolSchema
---@field fs fs.IFilesystem
local SearchSourceTool = class()

SearchSourceTool.name = "search_source"
SearchSourceTool.description = "Search filenames or file contents under a game-filesystem path. Results include repository-relative paths and content line numbers."
SearchSourceTool.input_schema = {
	type = "object",
	properties = {
		query = {type = "string", description = "Plain-text search query"},
		path = {type = "string", description = "File or directory to search, such as rizu or sphere/controllers"},
		mode = {type = "string", enum = {"content", "filename"}, description = "Search file contents or filenames"},
		case_sensitive = {type = "boolean", description = "Whether matching preserves letter case"},
		max_results = {type = "integer", minimum = 1, maximum = 50, description = "Maximum number of matches to return"},
		max_files = {type = "integer", minimum = 1, maximum = 2000, description = "Maximum number of files to scan"},
	},
	required = {"query", "path", "mode", "case_sensitive", "max_results", "max_files"},
	additionalProperties = false,
}
SearchSourceTool.annotations = {
	readOnlyHint = true,
	destructiveHint = false,
	idempotentHint = true,
	openWorldHint = false,
}
SearchSourceTool.schema = {
	type = "function",
	["function"] = {
		name = SearchSourceTool.name,
		description = SearchSourceTool.description,
		strict = true,
		parameters = SearchSourceTool.input_schema,
	},
}

---@param fs fs.IFilesystem
function SearchSourceTool:new(fs)
	self.fs = fs
end

---@param message string
---@return string
---@return true
local function fail(message)
	return "search_source error: " .. message, true
end

---@param path string
---@param name string
---@return string
local function join(path, name)
	if path == "" or path == "." then
		return name
	end
	return path .. "/" .. name
end

---@param value string
---@param query string
---@param case_sensitive boolean
---@return boolean
local function matches(value, query, case_sensitive)
	if not case_sensitive then
		value = value:lower()
		query = query:lower()
	end
	return value:find(query, 1, true) ~= nil
end

---@param args {[string]: any}
---@return string
---@return boolean? is_error
function SearchSourceTool:execute(args)
	if type(args.query) ~= "string" or args.query == "" then
		return fail("query must be a non-empty string")
	elseif type(args.path) ~= "string" or args.path == "" or args.path:find("\0", 1, true) then
		return fail("path must be a non-empty filesystem path")
	elseif args.mode ~= "content" and args.mode ~= "filename" then
		return fail("mode must be content or filename")
	elseif type(args.case_sensitive) ~= "boolean" then
		return fail("case_sensitive must be a boolean")
	elseif type(args.max_results) ~= "number" or args.max_results < 1 or args.max_results > 50 or args.max_results % 1 ~= 0 then
		return fail("max_results must be an integer from 1 to 50")
	elseif type(args.max_files) ~= "number" or args.max_files < 1 or args.max_files > 2000 or args.max_files % 1 ~= 0 then
		return fail("max_files must be an integer from 1 to 2000")
	end

	local root = args.path:gsub("\\", "/"):gsub("/+$", "")
	if root == "" then root = "." end
	local root_info = self.fs:getInfo(root)
	if not root_info then
		return fail("path not found")
	end

	local queue = {root}
	local queue_index = 1
	local files = 0
	local results = {}
	while queue_index <= #queue and #results < args.max_results and files < args.max_files do
		local path = queue[queue_index]
		queue_index = queue_index + 1
		local info = self.fs:getInfo(path)
		if info and info.type == "directory" then
			local items = self.fs:getDirectoryItems(path)
			table.sort(items)
			for _, name in ipairs(items) do
				table.insert(queue, join(path, name))
			end
		elseif info and info.type == "file" then
			files = files + 1
			if args.mode == "filename" then
				if matches(path, args.query, args.case_sensitive) then
					table.insert(results, path)
				end
			else
				local content = self.fs:read(path)
				if content then
					local line_number = 0
					for line in (content .. "\n"):gmatch("(.-)\n") do
						line_number = line_number + 1
						if matches(line, args.query, args.case_sensitive) then
							local text = utf8validate((line:gsub("\r$", "")))
							if #text > 500 then text = text:sub(1, 500) .. "...[truncated]" end
							table.insert(results, ("%s:%d: %s"):format(path, line_number, text))
							if #results >= args.max_results then break end
						end
					end
				end
			end
		end
	end

	local truncated = queue_index <= #queue and (#results >= args.max_results or files >= args.max_files)
	local output = {("search_source: %d matches in %d files%s"):format(#results, files, truncated and " (truncated)" or "")}
	for _, result in ipairs(results) do table.insert(output, result) end
	return utf8validate(table.concat(output, "\n"))
end

return SearchSourceTool
