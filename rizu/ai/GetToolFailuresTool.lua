local class = require("class")
local json = require("web.json")

---@class rizu.ai.GetToolFailuresTool
---@operator call: rizu.ai.GetToolFailuresTool
---@field name string
---@field description string
---@field input_schema table
---@field annotations mcp.ToolAnnotations
---@field schema aqua.openai.ToolSchema
---@field log rizu.ai.ToolFailureLog
local GetToolFailuresTool = class()

GetToolFailuresTool.name = "get_tool_failures"
GetToolFailuresTool.description = "Get recent failed AI-agent or MCP tool calls, including their arguments and errors, newest first."
GetToolFailuresTool.input_schema = {
	type = "object",
	properties = {
		limit = {type = "integer", minimum = 1, maximum = 100, description = "Maximum failures to return"},
		surface = {type = "string", enum = {"all", "agent", "mcp"}, description = "Tool-call surface to include"},
	},
	required = {"limit", "surface"},
	additionalProperties = false,
}
GetToolFailuresTool.annotations = {
	readOnlyHint = true,
	destructiveHint = false,
	idempotentHint = true,
	openWorldHint = false,
}
GetToolFailuresTool.schema = {
	type = "function",
	["function"] = {
		name = GetToolFailuresTool.name,
		description = GetToolFailuresTool.description,
		strict = true,
		parameters = GetToolFailuresTool.input_schema,
	},
}

---@param log rizu.ai.ToolFailureLog
function GetToolFailuresTool:new(log)
	self.log = log
end

---@param message string
---@return string
---@return true
local function fail(message)
	return "get_tool_failures error: " .. message, true
end

---@param args {[string]: any}
---@return string
---@return boolean? is_error
function GetToolFailuresTool:execute(args)
	if type(args.limit) ~= "number" or args.limit < 1 or args.limit > 100 or args.limit % 1 ~= 0 then
		return fail("limit must be an integer from 1 to 100")
	elseif args.surface ~= "all" and args.surface ~= "agent" and args.surface ~= "mcp" then
		return fail("surface must be all, agent, or mcp")
	end
	local failures = self.log:list(args.limit, args.surface)
	return json.encode({count = #failures, failures = failures})
end

return GetToolFailuresTool
