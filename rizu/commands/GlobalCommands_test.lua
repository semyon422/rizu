local GlobalCommands = require("rizu.commands.GlobalCommands")
local test = {}

---@param t testing.T
function test.registers_needle_live_argument(t)
	---@type rizu.command.Command?
	local command
	for _, candidate in ipairs(GlobalCommands({})) do
		if candidate.id == "global.needle" then command = candidate end
	end
	t:assert(command, "Needle command should be registered")
	---@cast command rizu.command.Command
	t:eq(command.arguments[1].name, "query")
	t:eq(command.arguments[1].type, "string")
end

---@param t testing.T
function test.omits_needle_gpu_probe_commands(t)
	for _, command in ipairs(GlobalCommands({})) do
		t:eq(command.id:find("global.needle_gpu", 1, true), nil)
	end
end

---@param t testing.T
function test.registers_set_resolution_command(t)
	---@type rizu.command.Command?
	local command
	for _, candidate in ipairs(GlobalCommands({})) do
		if candidate.id == "global.set_resolution" then command = candidate end
	end
	t:assert(command, "Set Resolution command should be registered")
	---@cast command rizu.command.Command
	local arg = command.arguments[1]
	t:eq(arg.name, "resolution")
	t:eq(arg.type, "string")
	t:eq(type(arg.choices), "function")
end

return test
