local ReadFileTool = require("rizu.ai.ReadFileTool")

local test = {}

---@param t testing.T
function test.reads_numbered_bounded_source_ranges(t)
	local requested_path
	local tool = ReadFileTool({
		read_func = function(path)
			requested_path = path
			return "first\nsecond\nthird"
		end,
	})

	local result, is_error = tool:execute({
		path = "rizu/example.lua",
		line_start = 2,
		line_end = 10,
	})

	t:eq(is_error, nil)
	t:eq(requested_path, "rizu/example.lua")
	t:eq(result, "rizu/example.lua:2-3 of 3\n2: second\n3: third")
end

---@param t testing.T
function test.rejects_sensitive_traversal_and_oversized_ranges(t)
	local tool = ReadFileTool({
		read_func = function()
			return "source"
		end,
		max_lines = 2,
	})

	local _, is_error = tool:execute({path = "userdata/ai.lua", line_start = 1, line_end = 1})
	t:eq(is_error, true)
	_, is_error = tool:execute({path = "rizu/../app_config.lua", line_start = 1, line_end = 1})
	t:eq(is_error, true)
	_, is_error = tool:execute({path = "app_config.lua", line_start = 1, line_end = 1})
	t:eq(is_error, true)
	_, is_error = tool:execute({path = "rizu/example.lua", line_start = 1, line_end = 3})
	t:eq(is_error, true)
end

---@param t testing.T
function test.exposes_read_only_openai_and_mcp_metadata(t)
	local tool = ReadFileTool({read_func = function() return "source" end})

	t:eq(tool.schema["function"].name, "read_file")
	t:eq(tool.schema["function"].parameters, tool.input_schema)
	t:eq(tool.annotations.readOnlyHint, true)
	t:eq(tool.annotations.openWorldHint, false)
end

---@param t testing.T
function test.bounds_character_output(t)
	local tool = ReadFileTool({
		read_func = function()
			return string.rep("x", 100)
		end,
		max_chars = 20,
	})

	local result = tool:execute({path = "rizu/example.lua", line_start = 1, line_end = 1})
	t:eq(#result, 35)
	t:eq(result:sub(-15), "\n...[truncated]")
end

return test
