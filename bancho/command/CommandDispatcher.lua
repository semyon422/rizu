--- In-chat command dispatcher.
---
--- Parses `/command args` or `!command args` from chat messages.
--- Supports privilege gating, hidden commands, and subcommand sets (e.g. `mp_*`).

local class = require("class")
local CommandSet = require("bancho.command.CommandSet")

--- Command dispatcher: registry and parser.
---@class bancho.command.CommandDispatcher
---@operator call: bancho.command.CommandDispatcher
---@field prefix string command prefix character
---@field commands bancho.command.Command[] flat command list
---@field command_sets bancho.command.CommandSet[] grouped command sets
local CommandDispatcher = class()

function CommandDispatcher:new(prefix)
	self.prefix = prefix or "!"
	self.commands = {}
	self.command_sets = {}
	return self
end

--- Register a flat command (not part of a set).
---@param triggers string[] trigger names
---@param callback fun(ctx: bancho.command.Context): string?
---@param priv integer
---@param hidden? boolean
function CommandDispatcher:register(triggers, callback, priv, hidden)
	self.commands[#self.commands + 1] = {
		triggers = triggers,
		callback = callback,
		priv = priv,
		hidden = hidden or false,
		doc = nil,
	}
end

--- Register a command set (grouped subcommands).
---@param set bancho.command.CommandSet
function CommandDispatcher:registerSet(set)
	self.command_sets[#self.command_sets + 1] = set
end

--- Check if a player has the required privilege.
---@param player bancho.model.Player
---@param required integer
---@return boolean
function CommandDispatcher:hasPriv(player, required)
	return bit.band(player.priv, required) ~= 0
end

--- Parse a command message and execute if matched.
--- Returns { response: string?, executed: boolean } or nil if no command matched.
---@param player bancho.model.Player
---@param recipient bancho.model.Channel|bancho.model.Player
---@param msg string raw message text
---@return {response: string?, executed: boolean}?
function CommandDispatcher:dispatch(player, recipient, msg)
	-- Check prefix
	if msg:sub(1, #self.prefix) ~= self.prefix then return nil end

	-- Parse: prefix trigger [args...]
	local rest = msg:sub(#self.prefix + 1)
	local parts = {}
	for word in rest:gmatch("%S+") do
		parts[#parts + 1] = word
	end

	if #parts == 0 then return nil end

	local trigger = parts[1]:lower()
	local args = {}
	for i = 2, #parts do
		args[#args + 1] = parts[i]
	end

	-- Build context
	local ctx = {
		player = player,
		trigger = trigger,
		args = args,
		recipient = recipient,
	}

	-- Search flat commands
	for _, cmd in ipairs(self.commands) do
		for _, t in ipairs(cmd.triggers) do
			if t == trigger then
				if not self:hasPriv(player, cmd.priv) then return nil end
				local response = cmd.callback(ctx)
				return { response = response, executed = true, hidden = cmd.hidden }
			end
		end
	end

	-- Search command sets
	for _, set in ipairs(self.command_sets) do
		if trigger == set.prefix then
			-- Subcommand: first arg is the subcommand name
			if #args == 0 then return nil end
			local sub_trigger = table.remove(args, 1):lower()
			ctx.trigger = sub_trigger

			for _, cmd in ipairs(set.commands) do
				for _, t in ipairs(cmd.triggers) do
					if t == sub_trigger then
						if not self:hasPriv(player, cmd.priv) then return nil end
						local response = cmd.callback(ctx)
						return { response = response, executed = true, hidden = cmd.hidden }
					end
				end
			end
			return nil -- No matching subcommand
		end
	end

	return nil -- No command matched
end

--- Generate help text for a player.
---@param player bancho.model.Player
---@return string
function CommandDispatcher:getHelp(player)
	local lines = {}
	table.insert(lines, "Commands:")

	for _, cmd in ipairs(self.commands) do
		if cmd.doc and self:hasPriv(player, cmd.priv) then
			table.insert(lines, string.format("  %s%s: %s", self.prefix, cmd.triggers[1], cmd.doc))
		end
	end

	for _, set in ipairs(self.command_sets) do
		if set.doc then
			table.insert(lines, string.format("  %s%s: %s", self.prefix, set.prefix, set.doc))
		end
		for _, cmd in ipairs(set.commands) do
			if cmd.doc and self:hasPriv(player, cmd.priv) then
				table.insert(lines, string.format("  %s%s %s: %s", self.prefix, set.prefix, cmd.triggers[1], cmd.doc))
			end
		end
	end

	return table.concat(lines, "\n")
end

return CommandDispatcher
