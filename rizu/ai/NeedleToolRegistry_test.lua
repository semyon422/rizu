local Registry = require("yi.command_palette.Registry")
local NeedleToolRegistry = require("rizu.ai.NeedleToolRegistry")

local test = {}

local function command(id, callback, arguments)
	return {id = id, title = id, description = id, arguments = arguments, callback = callback or function() end}
end

local function names(tool_set)
	local result = {}
	for _, tool in ipairs(tool_set.tools) do result[tool.name] = true end
	return result
end

---@param t testing.T
function test.context_allowlist(t)
	local registry = Registry()
	registry:registerGlobal(command("global.rate", nil, {{validate = function() return true end}}))
	registry:registerGlobal(command("global.screenshot"))
	registry:registerGlobal(command("global.screenshot_open"))
	registry:registerGlobal(command("global.exit"))
	local tools = NeedleToolRegistry(registry):snapshot()
	local present = names(tools)
	t:eq(present.set_playback_rate, true)
	t:eq(present.capture_screenshot, true)
	t:eq(present.exit, nil)
	t:eq(present.control_gameplay, nil)
	t:eq(tools.tools_json:find('"properties"', 1, true), nil)
	t:assert(tools.tools_json:find('"rate":{"type":"number","description":"Playback rate multiplier.","required":true}', 1, true))
	t:eq(tools.by_name.set_playback_rate.parameters.properties.rate.type, "number")

	registry:pushContext("gameplay", {
		command("gameplay.pause"), command("gameplay.resume"), command("gameplay.retry"),
		command("gameplay.quit"), command("gameplay.skip_intro"), command("gameplay.offset_decrease"),
		command("gameplay.offset_increase"), command("gameplay.offset_reset"),
	})
	present = names(NeedleToolRegistry(registry):snapshot())
	t:eq(present.control_gameplay, true)
	t:eq(present.adjust_local_offset, true)
end

---@param t testing.T
function test.parse_validation(t)
	local called = 0
	local tool = {
		name = "set_playback_rate", description = "rate", argument_order = {"rate"},
		parameters = {type = "object", properties = {rate = {type = "number"}}, required = {"rate"}},
		execute = function() called = called + 1 end,
	}
	local tool_set = {tools = {tool}, by_name = {[tool.name] = tool}, tools_json = "[]"}
	local call = assert(NeedleToolRegistry.parse(tool_set, '[{"name":"set_playback_rate","arguments":{"rate":1.2}}]'))
	t:eq(NeedleToolRegistry.format(tool_set, call), "set_playback_rate(rate = 1.2)")
	NeedleToolRegistry.execute(tool_set, call)
	t:eq(called, 1)
	local _, multi_error = NeedleToolRegistry.parse(tool_set, '[{"name":"set_playback_rate","arguments":{"rate":1}},{"name":"set_playback_rate","arguments":{"rate":2}}]')
	t:assert(multi_error:find("exactly one", 1, true))
	local _, extra_error = NeedleToolRegistry.parse(tool_set, '[{"name":"set_playback_rate","arguments":{"rate":1,"other":2}}]')
	t:assert(extra_error:find("unexpected argument", 1, true))
	local _, type_error = NeedleToolRegistry.parse(tool_set, '[{"name":"set_playback_rate","arguments":{"rate":"fast"}}]')
	t:assert(type_error:find("must be number", 1, true))
	local _, missing_error = NeedleToolRegistry.parse(tool_set, '[{"name":"set_playback_rate","arguments":{}}]')
	t:assert(missing_error:find("missing argument", 1, true))
	local _, unknown_error = NeedleToolRegistry.parse(tool_set, '[{"name":"exit","arguments":{}}]')
	t:assert(unknown_error:find("unknown tool", 1, true))
	local _, malformed_error = NeedleToolRegistry.parse(tool_set, "not json")
	t:assert(malformed_error:find("invalid tool-call JSON", 1, true))
end

---@param t testing.T
function test.enum_and_out_of_range_validation(t)
	local tool = {
		name = "example", description = "example", argument_order = {"mode", "value"},
		parameters = {type = "object", properties = {
			mode = {type = "string", enum = {"allowed"}},
			value = {type = "number"},
		}, required = {"mode", "value"}},
		execute = function() end,
	}
	local tool_set = {tools = {tool}, by_name = {[tool.name] = tool}, tools_json = "[]"}
	local _, enum_error = NeedleToolRegistry.parse(tool_set, '[{"name":"example","arguments":{"mode":"denied","value":1}}]')
	t:assert(enum_error:find("invalid value", 1, true))
	local _, range_error = NeedleToolRegistry.parse(tool_set, '[{"name":"example","arguments":{"mode":"allowed","value":1e999}}]')
	t:assert(range_error:find("invalid tool-call JSON", 1, true))
end

return test
