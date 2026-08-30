local class = require("class")
local json = require("web.json")

---@class rizu.ai.SourceLocation
---@field target string
---@field path string?
---@field line_start integer
---@field line_end integer
---@field what string
---@field name string?

---@class rizu.ai.SourceLocationTool
---@operator call: rizu.ai.SourceLocationTool
---@field name string
---@field description string
---@field input_schema table
---@field annotations mcp.ToolAnnotations
---@field schema openai.ToolSchema
---@field game sphere.GameController
local SourceLocationTool = class()

SourceLocationTool.name = "get_source_location"
SourceLocationTool.description = "Find the repository filename and line range for a runtime function using a dot-separated path rooted at game, such as game.network.request. Use read_file on the returned range to inspect its implementation."
SourceLocationTool.input_schema = {
	type = "object",
	properties = {
		target = {
			type = "string",
			description = "Runtime function path rooted at game, for example game.aiChatModel.send",
		},
	},
	required = {"target"},
	additionalProperties = false,
}
SourceLocationTool.annotations = {
	readOnlyHint = true,
	destructiveHint = false,
	idempotentHint = true,
	openWorldHint = false,
}
SourceLocationTool.schema = {
	type = "function",
	["function"] = {
		name = SourceLocationTool.name,
		description = SourceLocationTool.description,
		strict = true,
		parameters = SourceLocationTool.input_schema,
	},
}

---@param game sphere.GameController
function SourceLocationTool:new(game)
	self.game = game
end

---@param message string
---@return string
---@return true
local function fail(message)
	return "get_source_location error: " .. message, true
end

---@param args {[string]: any}
---@return string
---@return boolean? is_error
function SourceLocationTool:execute(args)
	local target = args.target
	if type(target) ~= "string" or not target:match("^game[%w_.]*$") then
		return fail("target must be a dot-separated path rooted at game")
	end
	---@type table|function
	local value = self.game
	local first = true
	for part in target:gmatch("[^.]+") --[[@as fun(): string]] do
		if first then
			first = false
			if part ~= "game" then
				return fail("target must be rooted at game")
			end
		elseif type(value) ~= "table" then
			return fail("cannot traverse through " .. part)
		else
			-- Runtime source paths intentionally traverse dynamically keyed game objects.
			---@diagnostic disable-next-line: no-unknown
			value = value[part]
			if value == nil then
				return fail("target does not exist")
			end
		end
	end
	if type(value) ~= "function" then
		return fail("target is not a function")
	end

	local info = assert(debug.getinfo(value, "Sln"))
	---@type string?
	local path
	if info.source:sub(1, 1) == "@" then
		path = info.source:sub(2):gsub("\\", "/")
	end
	---@type rizu.ai.SourceLocation
	local location = {
		target = target,
		path = path,
		line_start = info.linedefined,
		line_end = info.lastlinedefined,
		what = info.what,
		name = info.name,
	}
	return json.encode(location)
end

return SourceLocationTool
