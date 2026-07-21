local json = require("web.json")
local InspectRuntimeTool = require("rizu.ai.InspectRuntimeTool")

local test = {}

local function runtimeFunction()
	return true
end

---@param t testing.T
function test.inspects_nested_runtime_values(t)
	local service = {_private = 42, fn = runtimeFunction, invalid = "bad\255text"}
	service.self = service
	local tool = InspectRuntimeTool({service = service} --[[@as sphere.GameController]])
	local result = json.decode(tool:execute({target = "game.service", depth = 2, max_items = 20}))
	local items = {}
	for _, item in ipairs(result.inspection.items) do items[item.key] = item.value end

	t:eq(result.target, "game.service")
	t:eq(items._private.value, 42)
	t:eq(items.invalid.value, "bad?text")
	t:eq(items.fn.path, "rizu/ai/InspectRuntimeTool_test.lua")
	t:eq(items.self.reference, "game.service")
end

---@param t testing.T
function test.bounds_depth_and_items(t)
	local tool = InspectRuntimeTool({values = {a = 1, b = 2}} --[[@as sphere.GameController]])
	local result = json.decode(tool:execute({target = "game.values", depth = 1, max_items = 1}))
	t:eq(#result.inspection.items, 1)
	t:eq(result.inspection.truncated, true)

	result = json.decode(tool:execute({target = "game.values", depth = 0, max_items = 10}))
	t:eq(result.inspection.truncated, true)
	t:eq(#result.inspection.items, 0)
end

---@param t testing.T
function test.reports_missing_and_invalid_targets(t)
	local tool = InspectRuntimeTool({} --[[@as sphere.GameController]])
	local _, is_error = tool:execute({target = "game.missing", depth = 1, max_items = 10})
	t:eq(is_error, true)
	_, is_error = tool:execute({target = "os", depth = 1, max_items = 10})
	t:eq(is_error, true)
end

return test
