--- Command set for grouped subcommands (e.g. `mp_*`).

local class = require("class")

--- Command definition.
---@class bancho.command.Command
---@field triggers string[] command trigger names (e.g. {"start", "st"})
---@field callback fun(ctx: bancho.command.Context): string? response text or nil
---@field priv integer required privilege bitmask
---@field hidden boolean if true, only staff see the message
---@field doc string? help text

--- Command execution context.
---@class bancho.command.Context
---@field player bancho.model.Player
---@field trigger string command trigger used
---@field args string[] parsed arguments
---@field recipient bancho.model.Channel|bancho.model.Player channel or player being messaged

--- Command set for grouped subcommands (e.g. `mp_*`).
---@class bancho.command.CommandSet
---@operator call: bancho.command.CommandSet
---@field prefix string prefix (e.g. "mp")
---@field doc string? help text for the set
---@field commands bancho.command.Command[]
local CommandSet = class()

function CommandSet:new(prefix, doc)
	self.prefix = prefix
	self.doc = doc
	self.commands = {}
	return self
end

--- Add a command to this set.
--- The function name should be `{prefix}_{trigger}` or explicit triggers can be provided.
---@param priv integer
---@param aliases? string[] additional trigger aliases
---@param hidden? boolean
---@return fun(callback: fun(ctx: bancho.command.Context): string?): fun(ctx: bancho.command.Context): string? decorator
function CommandSet:add(priv, aliases, hidden)
	local self = self
	return function(callback)
		local triggers = aliases or {}
		table.insert(triggers, self.prefix)
		self.commands[#self.commands + 1] = {
			triggers = triggers,
			callback = callback,
			priv = priv,
			hidden = hidden or false,
			doc = nil,
		}
	end
end

return CommandSet
