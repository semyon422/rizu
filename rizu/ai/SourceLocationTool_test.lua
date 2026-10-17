local json = require("web.json")
local SourceLocationTool = require("rizu.ai.SourceLocationTool")

local test = {}

local function locatedFunction()
	return true
end

---@param t testing.T
function test.locates_public_runtime_function(t)
	local tool = SourceLocationTool({service = {call = locatedFunction}} --[[@as sphere.GameController]])
	local result, is_error = tool:execute({target = "game.service.call"})
	local location = json.decode(result)

	t:eq(is_error, nil)
	t:eq(location.target, "game.service.call")
	t:eq(location.path, "rizu/ai/SourceLocationTool_test.lua")
	t:eq(location.what, "Lua")
	t:assert(location.line_start > 0)
	t:assert(location.line_end >= location.line_start)
end

---@param t testing.T
function test.accepts_private_and_rejects_missing_and_non_function_targets(t)
	local tool = SourceLocationTool({
		service = {
			_private = locatedFunction,
			value = 1,
		},
	} --[[@as sphere.GameController]])

	local result, is_error = tool:execute({target = "game.service._private"})
	t:eq(is_error, nil)
	t:eq(json.decode(result).target, "game.service._private")
	_, is_error = tool:execute({target = "game.service.missing"})
	t:eq(is_error, true)
	_, is_error = tool:execute({target = "game.service.value"})
	t:eq(is_error, true)
	_, is_error = tool:execute({target = "os.execute"})
	t:eq(is_error, true)
end

---@param t testing.T
function test.exposes_read_only_openai_and_mcp_metadata(t)
	local tool = SourceLocationTool({} --[[@as sphere.GameController]])

	t:eq(tool.schema["function"].name, "get_source_location")
	t:eq(tool.schema["function"].parameters, tool.input_schema)
	t:eq(tool.annotations.readOnlyHint, true)
	t:eq(tool.annotations.openWorldHint, false)
end

return test
