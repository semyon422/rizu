local class = require("class")
local json = require("web.json")
local utf8validate = require("utf8validate")

---@class rizu.ai.InspectRuntimeTool
---@operator call: rizu.ai.InspectRuntimeTool
---@field name string
---@field description string
---@field input_schema table
---@field annotations mcp.ToolAnnotations
---@field schema aqua.openai.ToolSchema
---@field game sphere.GameController
local InspectRuntimeTool = class()

InspectRuntimeTool.name = "inspect_runtime"
InspectRuntimeTool.description = "Inspect a value reachable through a dot-separated game path without evaluating Lua code. Returns types, table fields, metatables, and function source locations."
InspectRuntimeTool.input_schema = {
	type = "object",
	properties = {
		target = {type = "string", description = "Runtime path rooted at game, such as game.network.diagnostics"},
		depth = {type = "integer", minimum = 0, maximum = 4, description = "Nested table depth to inspect"},
		max_items = {type = "integer", minimum = 1, maximum = 100, description = "Maximum total table fields to include"},
	},
	required = {"target", "depth", "max_items"},
	additionalProperties = false,
}
InspectRuntimeTool.annotations = {
	readOnlyHint = true,
	destructiveHint = false,
	idempotentHint = true,
	openWorldHint = false,
}
InspectRuntimeTool.schema = {
	type = "function",
	["function"] = {
		name = InspectRuntimeTool.name,
		description = InspectRuntimeTool.description,
		strict = true,
		parameters = InspectRuntimeTool.input_schema,
	},
}

---@param game sphere.GameController
function InspectRuntimeTool:new(game)
	self.game = game
end

---@param message string
---@return string
---@return true
local function fail(message)
	return "inspect_runtime error: " .. message, true
end

---@param value any
---@return string
local function safeString(value)
	local ok, result = pcall(tostring, value)
	if not ok then return "<tostring failed>" end
	result = utf8validate(result)
	if #result > 1000 then
		result = utf8validate(result:sub(1, 1000)) .. "...[truncated]"
	end
	return result
end

---@param value function
---@return table
local function describeFunction(value)
	local info = assert(debug.getinfo(value, "Sln"))
	local path
	if info.source:sub(1, 1) == "@" then
		path = info.source:sub(2):gsub("\\", "/")
	end
	return {
		type = "function",
		path = path,
		line_start = info.linedefined,
		line_end = info.lastlinedefined,
		what = info.what,
		name = info.name,
	}
end

---@class rizu.ai.RuntimeInspectionState
---@field remaining integer
---@field seen {[table]: string}

---@param value any
---@param depth integer
---@param path string
---@param state rizu.ai.RuntimeInspectionState
---@return table
local function describeValue(value, depth, path, state)
	local value_type = type(value)
	if value_type == "nil" then
		return {type = "nil"}
	elseif value_type == "boolean" or value_type == "number" then
		return {type = value_type, value = value}
	elseif value_type == "string" then
		return {type = "string", value = safeString(value), bytes = #value}
	elseif value_type == "function" then
		return describeFunction(value)
	elseif value_type ~= "table" then
		return {type = value_type, value = safeString(value)}
	end

	local previous_path = state.seen[value]
	if previous_path then
		return {type = "table", reference = previous_path}
	end
	state.seen[value] = path
	local result = {type = "table", items = {}}
	if depth <= 0 then
		result.truncated = true
		return result
	end

	local keys = {}
	for key in next, value do table.insert(keys, key) end
	table.sort(keys, function(a, b)
		local type_a, type_b = type(a), type(b)
		if type_a ~= type_b then return type_a < type_b end
		return safeString(a) < safeString(b)
	end)
	for _, key in ipairs(keys) do
		if state.remaining <= 0 then
			result.truncated = true
			break
		end
		state.remaining = state.remaining - 1
		local key_text = safeString(key)
		table.insert(result.items, {
			key = key_text,
			key_type = type(key),
			value = describeValue(value[key], depth - 1, path .. "." .. key_text, state),
		})
	end
	local metatable = getmetatable(value)
	if metatable then
		result.metatable = describeValue(metatable, depth - 1, path .. ".<metatable>", state)
	end
	return result
end

---@param args {[string]: any}
---@return string
---@return boolean? is_error
function InspectRuntimeTool:execute(args)
	local target = args.target
	if type(target) ~= "string" or not target:match("^game[%w_.]*$") then
		return fail("target must be a dot-separated path rooted at game")
	elseif type(args.depth) ~= "number" or args.depth < 0 or args.depth > 4 or args.depth % 1 ~= 0 then
		return fail("depth must be an integer from 0 to 4")
	elseif type(args.max_items) ~= "number" or args.max_items < 1 or args.max_items > 100 or args.max_items % 1 ~= 0 then
		return fail("max_items must be an integer from 1 to 100")
	end

	local value = self.game
	local first = true
	for part in target:gmatch("[^.]+") do
		if first then
			first = false
			if part ~= "game" then return fail("target must be rooted at game") end
		elseif type(value) ~= "table" then
			return fail("cannot traverse through " .. part)
		else
			value = value[part]
			if value == nil then return fail("target does not exist") end
		end
	end

	return json.encode({
		target = target,
		inspection = describeValue(value, args.depth, target, {remaining = args.max_items, seen = {}}),
	})
end

return InspectRuntimeTool
