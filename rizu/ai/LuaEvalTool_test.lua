local json = require("web.json")
local LuaEvalTool = require("rizu.ai.LuaEvalTool")

local test = {}

---@param t testing.T
function test.evaluates_expressions_chunks_and_prints(t)
	local tool = LuaEvalTool({value = 7})
	local result = json.decode(tool:execute({code = "game.value + 1"}))
	t:eq(result.ok, true)
	t:eq(result.values[1], "8")

	result = json.decode(tool:execute({code = "print('hello', game.value); return game.value"}))
	t:eq(result.ok, true)
	t:eq(result.output, "hello\t7")
	t:eq(result.values[1], "7")
end

---@param t testing.T
function test.exposes_process_globals_without_leaking_assignments(t)
	local tool = LuaEvalTool({})
	local result = json.decode(tool:execute({code = "temporary_ai_global = 1; return _VERSION == _G._VERSION, type(os.clock) == 'function', type(require) == 'function'"}))
	t:eq(result.ok, true)
	t:eq(result.values[1], "true")
	t:eq(result.values[2], "true")
	t:eq(result.values[3], "true")
	t:eq(rawget(_G, "temporary_ai_global"), nil)
end

---@param t testing.T
function test.reports_compile_runtime_and_input_errors(t)
	local tool = LuaEvalTool({})
	local result = json.decode(tool:execute({code = "local ="}))
	t:eq(result.ok, false)
	result = json.decode(tool:execute({code = "error('boom')"}))
	t:eq(result.ok, false)
	t:assert(result.error:find("boom", 1, true))
	result = json.decode(tool:execute({code = ""}))
	t:eq(result.error, "code must be a non-empty string")
end

---@param t testing.T
function test.rejects_bytecode_and_bounds_output(t)
	local tool = LuaEvalTool({}, {output_limit = 8})
	local result = json.decode(tool:execute({code = string.char(27) .. "bad"}))
	t:eq(result.ok, false)

	result = json.decode(tool:execute({code = "print('123456789')"}))
	t:eq(result.ok, true)
	t:eq(result.output, "12345678\n...[truncated]")
end

return test
