local GlobalCommands = require("yi.command_palette.GlobalCommands")

local test = {}

---@param t testing.T
function test.opens_ai_chat(t)
	local opened = false
	local ui = {
		overlay = {
			attachChat = function()
				opened = true
			end,
		},
	}
	local command
	for _, candidate in ipairs(GlobalCommands.get({}, ui)) do
		if candidate.id == "global.ai_chat" then
			command = candidate
			break
		end
	end
	t:assert(command, "AI chat command should be registered")
	command.callback({})
	t:eq(opened, true)
end

return test
