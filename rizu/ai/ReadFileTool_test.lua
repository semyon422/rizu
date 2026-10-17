local FakeFilesystem = require("fs.FakeFilesystem")
local ReadFileTool = require("rizu.ai.ReadFileTool")

local test = {}

---@param path string
---@param content string
---@return rizu.ai.ReadFileTool
local function makeTool(path, content)
	local fs = FakeFilesystem()
	local directory = path:match("^(.*)/[^/]+$")
	if directory then fs:createDirectory(directory) end
	assert(fs:write(path, content))
	return ReadFileTool(fs)
end

---@param t testing.T
function test.reads_numbered_bounded_source_ranges(t)
	local tool = makeTool("rizu/example.lua", "first\nsecond\nthird")

	local result, is_error = tool:execute({
		path = "rizu/example.lua",
		line_start = 2,
		line_end = 10,
	})

	t:eq(is_error, nil)
	t:eq(result, "rizu/example.lua:2-3 of 3\n2: second\n3: third")
end

---@param t testing.T
function test.accepts_unrestricted_paths_and_line_ranges(t)
	local tool = makeTool("userdata/ai.lua", "first\nsecond\nthird")

	local result, is_error = tool:execute({path = "userdata/ai.lua", line_start = 1, line_end = 1000})
	t:eq(is_error, nil)
	t:eq(result, "userdata/ai.lua:1-3 of 3\n1: first\n2: second\n3: third")
end

---@param t testing.T
function test.exposes_read_only_openai_and_mcp_metadata(t)
	local tool = makeTool("source.lua", "source")

	t:eq(tool.schema["function"].name, "read_file")
	t:eq(tool.schema["function"].parameters, tool.input_schema)
	t:eq(tool.annotations.readOnlyHint, true)
	t:eq(tool.annotations.openWorldHint, false)
end

---@param t testing.T
function test.bounds_character_output(t)
	local tool = makeTool("rizu/example.lua", string.rep("x", 100))
	tool.max_chars = 20

	local result = tool:execute({path = "rizu/example.lua", line_start = 1, line_end = 1})
	t:eq(#result, 35)
	t:eq(result:sub(-15), "\n...[truncated]")
end

---@param t testing.T
function test.replaces_invalid_utf8(t)
	local tool = makeTool("binary.data", "bad\255text")
	local result = tool:execute({path = "binary.data", line_start = 1, line_end = 1})
	t:assert(result:find("bad?text", 1, true))
end

---@param t testing.T
function test.keeps_truncated_output_valid_utf8(t)
	local tool = makeTool("text.data", "ééé")
	tool.max_chars = 23
	local result = tool:execute({path = "text.data", line_start = 1, line_end = 1})
	t:eq(result, "text.data:1-1 of 1\n1: ?\n...[truncated]")
end

return test
