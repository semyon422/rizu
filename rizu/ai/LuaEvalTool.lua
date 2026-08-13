local class = require("class")
local brand = require("brand")
local json = require("web.json")
local pprint = require("pprint")
local safeload = require("safeload")
local table_util = require("table_util")

---@class rizu.ai.LuaEvalTool
---@operator call: rizu.ai.LuaEvalTool
---@field name string
---@field description string
---@field input_schema table
---@field annotations mcp.ToolAnnotations
---@field schema aqua.openai.ToolSchema
---@field game sphere.GameController
---@field output_limit integer
local LuaEvalTool = class()

LuaEvalTool.name = "lua_eval"
LuaEvalTool.output_limit = 16384
LuaEvalTool.description = ("Evaluate LuaJIT code in the running %s game. The global 'game' is the GameController. Use return values for observations."):format(brand.name)
LuaEvalTool.input_schema = {
	type = "object",
	properties = {
		code = {
			type = "string",
			description = "Lua expression or chunk to evaluate",
		},
	},
	required = {"code"},
	additionalProperties = false,
}
LuaEvalTool.annotations = {
	readOnlyHint = false,
	destructiveHint = true,
	openWorldHint = true,
}
LuaEvalTool.schema = {
	type = "function",
	["function"] = {
		name = "lua_eval",
		description = LuaEvalTool.description,
		strict = true,
		parameters = LuaEvalTool.input_schema,
	},
}

---@param game sphere.GameController
---@param options {output_limit: integer?}?
function LuaEvalTool:new(game, options)
	options = options or {}
	self.game = game
	self.output_limit = options.output_limit or self.output_limit
end

---@param value any
---@return string
local function formatValue(value)
	local colored = pprint.colored
	pprint.colored = false
	local ok, result = pcall(pprint.dump, value)
	pprint.colored = colored
	if ok then
		return result
	end
	return tostring(value)
end

---@param output string
---@param limit integer
---@return string
local function truncate(output, limit)
	if #output <= limit then
		return output
	end
	return output:sub(1, limit) .. "\n...[truncated]"
end

---@param printed string[]
---@return table
function LuaEvalTool:createEnvironment(printed)
	local env = {
		game = self.game,
		print = function(...)
			---@type string[]
			local values = {}
			for i = 1, select("#", ...) do
				values[i] = tostring(select(i, ...))
			end
			table.insert(printed, table.concat(values, "\t"))
		end,
	}
	env._G = env
	return setmetatable(env, {__index = _G})
end

---@param code string
---@param env table
---@return function?
---@return string?
local function compile(code, env)
	local ok, fn = pcall(safeload, "return " .. code, env)
	if ok then
		return fn
	end
	ok, fn = pcall(safeload, code, env)
	if ok then
		return fn
	end
	return nil, tostring(fn)
end

---@param args {[string]: any}
---@return string
---@return boolean is_error
function LuaEvalTool:execute(args)
	if type(args.code) ~= "string" or args.code == "" then
		return json.encode({ok = false, error = "code must be a non-empty string"}), true
	end

	local printed = {}
	local fn, compile_err = compile(args.code, self:createEnvironment(printed))
	if not fn then
		return json.encode({ok = false, error = compile_err}), true
	end
	local results = table_util.pack(xpcall(fn, debug.traceback))

	if not results[1] then
		return json.encode({
			ok = false,
			error = truncate(tostring(results[2]), self.output_limit),
			output = truncate(table.concat(printed, "\n"), self.output_limit),
		}), true
	end

	local values = {}
	local remaining = self.output_limit
	for i = 2, results.n do
		if remaining <= 0 then
			table.insert(values, "...[truncated]")
			break
		end
		local value = truncate(formatValue(results[i]), remaining)
		table.insert(values, value)
		remaining = remaining - #value
	end
	return json.encode({
		ok = true,
		output = truncate(table.concat(printed, "\n"), self.output_limit),
		values = values,
	}), false
end

return LuaEvalTool
