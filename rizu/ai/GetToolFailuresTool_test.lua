local json = require("web.json")
local GetToolFailuresTool = require("rizu.ai.GetToolFailuresTool")
local ToolFailureLog = require("rizu.ai.ToolFailureLog")

local test = {}

---@param t testing.T
function test.returns_filtered_failures_newest_first(t)
	local time = 100
	local log = ToolFailureLog({max_entries = 3, get_time = function() return time end})
	log:add("agent", "first", {value = 1}, "bad")
	time = 101
	log:add("mcp", "second", {value = 2}, "worse")
	time = 102
	log:add("agent", "third", {value = 3}, "bad\255bytes")
	time = 103
	log:add("agent", "fourth", {value = 4}, "latest")

	local tool = GetToolFailuresTool(log)
	local result = json.decode(tool:execute({limit = 2, surface = "agent"}))
	t:eq(result.count, 2)
	t:eq(result.failures[1].tool, "fourth")
	t:eq(result.failures[2].tool, "third")
	t:eq(result.failures[2].error, "bad?bytes")
	t:eq(result.failures[2].timestamp, 102)

	result = json.decode(tool:execute({limit = 100, surface = "all"}))
	t:eq(result.count, 3)
	t:eq(result.failures[3].tool, "second")
end

---@param t testing.T
function test.validates_arguments_and_metadata(t)
	local tool = GetToolFailuresTool(ToolFailureLog())
	local _, is_error = tool:execute({limit = 0, surface = "all"})
	t:eq(is_error, true)
	t:eq(tool.schema["function"].name, "get_tool_failures")
	t:eq(tool.annotations.readOnlyHint, true)
end

return test
