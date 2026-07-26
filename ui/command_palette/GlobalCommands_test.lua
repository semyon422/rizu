local GlobalCommands = require("ui.command_palette.GlobalCommands")

local test = {}

---@param t testing.T
function test.registers_needle_live_argument(t)
	local command
	for _, candidate in ipairs(GlobalCommands.get({}, nil)) do
		if candidate.id == "global.needle" then command = candidate end
	end
	t:assert(command, "Needle command should be registered")
	t:eq(command.arguments[1].name, "query")
	t:eq(command.arguments[1].type, "string")
end

---@param t testing.T
function test.omits_needle_gpu_probe_commands(t)
	for _, command in ipairs(GlobalCommands.get({}, nil)) do
		t:eq(command.id:find("global.needle_gpu", 1, true), nil)
	end
end

return test
