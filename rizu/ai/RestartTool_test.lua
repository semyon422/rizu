local RestartTool = require("rizu.ai.RestartTool")

local test = {}

---@param t testing.T
function test.requests_restart(t)
	local restarted = false
	local tool = RestartTool(function()
		restarted = true
	end)

	local result = tool:execute({})
	t:eq(restarted, true)
	t:eq(result, "Game restart requested. MCP will return after startup.")
	t:eq(tool.annotations.destructiveHint, true)
	t:eq(tool.annotations.readOnlyHint, false)
end

return test
