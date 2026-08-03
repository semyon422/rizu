local class = require("class")

-- Manages global and contextual screen-specific commands.
---@class rizu.command.Registry
---@operator call: rizu.command.Registry
---@field global_commands rizu.command.Command[]
---@field contextual_commands {[string]: rizu.command.Command[]}
---@field active_contexts string[]
local Registry = class()

function Registry:new()
	self.global_commands = {}
	self.contextual_commands = {}
	self.active_contexts = {}
end

--- Registers a command globally.
---@param command rizu.command.Command
function Registry:registerGlobal(command)
	table.insert(self.global_commands, command)
end

--- Push a screen context and its associated commands.
---@param context_name string
---@param commands rizu.command.Command[]
function Registry:pushContext(context_name, commands)
	self.contextual_commands[context_name] = commands
	for _, name in ipairs(self.active_contexts) do
		if name == context_name then return end
	end
	table.insert(self.active_contexts, context_name)
end

--- Removes a screen context.
---@param context_name string
function Registry:popContext(context_name)
	self.contextual_commands[context_name] = nil
	for i, name in ipairs(self.active_contexts) do
		if name == context_name then
			table.remove(self.active_contexts, i)
			break
		end
	end
end

--- Gets all currently active commands (Global + Active Contexts).
---@return rizu.command.Command[] active_commands
function Registry:getActiveCommands()
	---@type rizu.command.Command[]
	local list = {}
	for _, cmd in ipairs(self.global_commands) do
		table.insert(list, cmd)
	end
	for _, ctx_name in ipairs(self.active_contexts) do
		local cmds = self.contextual_commands[ctx_name]
		if cmds then
			for _, cmd in ipairs(cmds) do
				table.insert(list, cmd)
			end
		end
	end
	return list
end


return Registry
