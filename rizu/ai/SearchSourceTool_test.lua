local FakeFilesystem = require("fs.FakeFilesystem")
local SearchSourceTool = require("rizu.ai.SearchSourceTool")

local test = {}

---@return rizu.ai.SearchSourceTool
local function makeTool()
	local fs = FakeFilesystem()
	fs:createDirectory("rizu/sub")
	assert(fs:write("rizu/A.lua", "local Network = {}\nreturn Network"))
	assert(fs:write("rizu/sub/B.txt", "network lower\nbad\255network"))
	return SearchSourceTool(fs)
end

---@param t testing.T
function test.searches_content_recursively(t)
	local result = makeTool():execute({
		query = "network",
		path = "rizu",
		mode = "content",
		case_sensitive = false,
		max_results = 10,
		max_files = 10,
	})
	t:assert(result:find("rizu/A.lua:1: local Network", 1, true))
	t:assert(result:find("rizu/sub/B.txt:2: bad?network", 1, true))
end

---@param t testing.T
function test.searches_filenames_and_bounds_results(t)
	local result = makeTool():execute({
		query = ".",
		path = "rizu",
		mode = "filename",
		case_sensitive = true,
		max_results = 1,
		max_files = 10,
	})
	t:assert(result:find("1 matches", 1, true))
	t:assert(result:find("rizu/A.lua", 1, true))
	t:eq(result:find("B.txt", 1, true), nil)
end

---@param t testing.T
function test.reports_invalid_inputs(t)
	local _, empty_query_error = makeTool():execute({query = "", path = "rizu", mode = "content", case_sensitive = true, max_results = 1, max_files = 10})
	t:eq(empty_query_error, true)
	local _, missing_path_error = makeTool():execute({query = "x", path = "missing", mode = "content", case_sensitive = true, max_results = 1, max_files = 10})
	t:eq(missing_path_error, true)
end

return test
