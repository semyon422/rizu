local class = require("class")

---@class rizu.ai.RestartTool
---@operator call: rizu.ai.RestartTool
---@field name string
---@field description string
---@field input_schema table
---@field annotations mcp.ToolAnnotations
---@field restart fun()
local RestartTool = class()

RestartTool.name = "restart_game"
RestartTool.description = "Restart the running game through the LÖVE event loop. MCP is temporarily unavailable while the game starts again."
RestartTool.input_schema = {
	type = "object",
	additionalProperties = false,
}
RestartTool.annotations = {
	readOnlyHint = false,
	destructiveHint = true,
	idempotentHint = false,
	openWorldHint = false,
}

---@param restart (fun())?
function RestartTool:new(restart)
	self.restart = restart or function()
		love.event.quit("restart")
	end
end

---@param args {[string]: any}
---@return string
function RestartTool:execute(args)
	self.restart()
	return "Game restart requested. MCP will return after startup."
end

return RestartTool
